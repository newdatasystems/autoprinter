DECLARE INTEGER EnumPorts IN winspool.drv AS DLL_EnumPorts;
	STRING cName, ;
	INTEGER nLevel, ;
	INTEGER cBuffer, ;
	INTEGER nBufLen, ;
	INTEGER @nNeeded, ;
	INTEGER @nReturned

DECLARE INTEGER GetLastError IN kernel32 AS DLL_GetLastError

SET PROC TO clsheap ADDITIVE

LOCAL loPortEnum
loPortEnum=CREATEOBJECT('enumports')
return loPortEnum

DEFINE CLASS enumports AS custom
	cServerName=''  && if the servername is null enum local ports
	PROTECTED nLevel,oHeap,nBufSize,nHeapAlloc,nReturned,nNeeded,cBuffer
	PROTECTED aPorts[1]
	nLevel=2
	aPorts=0
	nBufSize=2400
	nHeapAlloc=NULL
	cBuffer=''
	nReturned=0
	nNeeded=0

	proc init
		parameters nSetBuf
		if type('nSetBuf')='N' and nSetBuf>0
			nBufSize=nSetBuf
		endif
		this.oHeap=CREATEOBJECT('HEAP')
	endproc

	proc destroy
		*	make sure to deref the Heap object before destroy;  this ensures no hanging refs
		*	and that a private heap will go away at destruct
		IF ! ISNULL(this.nHeapAlloc)
			*	We have previously built a NETRESOURCE;  we're building a new one,
			*	so deallocate the old one's string buffer
			this.oHeap.DeAlloc(this.nHeapAlloc)
			this.nHeapAlloc = NULL
		ENDIF
		this.oHeap = ''
		DODEFAULT()
	endproc

	* LISTPORTS*
	*
	* use DLL_EnumPorts to get the list of ports as .cServerName
	*
	* NOTE: if the buffer isn't big enough to hold the results of this then DLL_EnumPrinters
	* returns 1 and GetLastError() returns 122.  That causes this function to loop, reallocating
	* the needed memory.
	*
	* RETURNS: 0 if successfull.  Error code of the last error otherwise
	proc ListPorts
		local lnStatus,lcBuffer,lnNeededT,lnReturnedT,lcServerT
		with this
			store 0 to lnNeededT,lnReturnedT
			DO WHILE .t.
				if !ISNULL(.nHeapAlloc)  && delete the old allocation if we're trying again
					.oHeap.DeAlloc(.nHeapAlloc)
					.nHeapAlloc=NULL
					if .nNeeded>.nBufSize
						.nBufSize=.nNeeded
					endif
				endif
				.nHeapAlloc=.oHeap.Alloc(.nBufSize)  && create a new heap of size nBufSize
				.oHeap.CopyTo(.nHeapAlloc,SPACE(.nBufSize))  && fill it with blanks
				lcServerT = IIF(TYPE('.cServerName')#'C',NULL,.cServerName)
				lnStatus=DLL_EnumPorts(lcServerT,.nLevel,.nHeapAlloc,.nBufSize,@lnNeededT,@lnReturnedT)
				.nNeeded=lnNeededT
				.nReturned=lnReturnedT
				IF lnStatus=0 AND DLL_GetLastError()=122  && loop if we didn't have enough space
					loop
				ENDIF
				EXIT
			ENDDO
			if lnStatus#0  &&  succesful
				IF .nReturned>0  && there are results so parse them out and build Port_Info_2 objects
					lcBuffer = .oHeap.CopyFrom(.nHeapAlloc)
					DIMENSION .aPorts[.nReturned]
					for i=0 to .nReturned-1
						.aPorts[i+1]=CREATEOBJECT('PORT_INFO_2',SUBS(lcBuffer,(20 * i)+1,20))
					ENDFOR
				ENDIF
				lnStatus=0
			ELSE  && failure
				lnStatus=DLL_GetLastError()
				if MESSAGEBOX(ErrorMessage(lnStatus)+CHR(13)+'DEBUG?',4,'Error In Enumeration of Ports')=6
					WAIT WINDOW 'EnumPorts Failure'
				endif
			endif
			return lnStatus
		endwith
	endproc

	* GETPort *
	*
	* If 'lnIndex' is numeric it returns the Port_Info_2 object at
	* that location in aPorts[] array.
	*
	* ==PARAMS==
	* lnIndex (N) - an index to the array of the port to return
	* ==PARAMS==
	*
	* RETURNS: the Port_Info_2 object identified by 'lnIndex' or EMPTY STRING
	PROCEDURE getPort
		PARAMETERS lnIndex
		IF TYPE('lnIndex')='N' and BETWEEN(lnIndex,1,this.nReturned)
			RETURN this.aPorts[lnIndex]
		ENDIF
		RETURN ''
	endproc

	* GETNEEDED *
	*
	* use to tell if the initial buffer needs more space
	* or the size of the buffer
	proc getNeeded
		return this.nNeeded
	endproc

	* GETCOUNT *
	*
	* returns the number of printer entries returned by the EnumPorts() function
	PROCEDURE getCount
		RETURN this.nReturned
	endproc

ENDDEFINE

* typedef struct _PORT_INFO_2 {
*   LPTSTR pPortName;
*   LPTSTR pMonitorName
*   LPTSTR pDescription;
*   DWORD fPortType;
*   DWORD Reserved;
* }
DEFINE CLASS port_info_2 AS custom
	cPortName=''
	cMonitorName=''
	cDescription=''
	nPortType=0
	PROTECTED cPortInfo

	proc init
		parameters tcRawInfo
		if type('tcRawInfo')='C'
			this.cPortInfo=tcRawInfo
			this.ParseInfo()
		endif
	endproc

	* PARSEINFO *
	* parses the twelve byte structure into two pointers and an integer
	proc ParseInfo
		local lPtr
		with this
			if TYPE('.cPortInfo')='C' and !EMPTY(.cPortInfo)
				.cPortName=getStringFromDWord(SUBSTR(.cPortInfo,1,4))
				.cMonitorName=getStringFromDWord(SUBSTR(.cPortInfo,5,4))
				.cDescription=getStringFromDWord(SUBSTR(.cPortInfo,9,4))
				.nPortType=DWORDtoNUM(SUBSTR(.cPortInfo,13,4))
			endif
		endwith
	endproc

#if .f.
	* STATUSSTRING *
	*
	* translate the number held in this.nStatus into the series of strings
	* denoting the state of the printer
	*
	* RETURNS: a string containing the various states of the printer
	PROCEDURE StatusString
		RETURN PrnStatusString(this.nState)
	ENDPROC
#endif

ENDDEFINE

proc getStringFromDWORD
	parameters tcDWORD
	local lcRetVal,lPtr

	store '' to lcRetVal

	if type('tcDWord')='C' and !EMPTY(tcDWORD)
		lPtr=DWORDtoNUM(tcDWord)
		lcRetVal=IIF(lPtr=0,'',GetMemString(lPtr))
	endif

return lcRetVal