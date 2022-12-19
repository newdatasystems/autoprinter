PROCEDURE DocPrinter
	LPARAMETERS tcPrinter,tcFileName,tcJobName

	LOCAL hPrinter
	LOCAL cString
	LOCAL nWritten
	LOCAL hFile
	LOCAL loHeap,lhDocName,lhDocType
	STORE 0 TO hPrinter,hFile,nWritten
	
	* get the printer
	IF EMPTY(m.tcPrinter)
		m.cPrinter=GETPRINTER()
		IF ISBLANK(m.cPrinter)
			RETURN .F.
		ENDIF
	ENDIF 
	
	* get the file
	IF EMPTY(m.tcFileName)
		tcFileName = GETFILE()
	ENDIF 

	IF .NOT.FILE(m.tcFileName)
		MESSAGEBOX("File "+m.tcFileName+" not found!",16,"Print")
		RETURN .F.
	ENDIF

	* open the file
	m.hFile=FOPEN(m.tcFileName)
	IF m.hFile<0
		MESSAGEBOX("Can't open file "+m.tcFileName+"!",16,"Print")
		RETURN .F.
	ENDIF

	* declare the API functions
	DO decl

	* open the printer
	IF API_OpenPrinter(m.tcPrinter,@m.hPrinter,0)=0
		FCLOSE(m.hFile)
		sub_APIError('Error opening printer.')
		RETURN .F.
	ENDIF

	* allocate space for the printer name string
	loHeap = NEWOBJECT('Heap','CLSHeap.Prg')
	IF VARTYPE(tcJobName)='C' AND !EMPTY(tcJobName)
		lhDocName = loHeap.AllocString(tcJobName)
	ENDIF 
	lhDocType = loHeap.AllocString('RAW')
		
	* activate the printer
	IF API_StartDocPrinter(m.hPrinter,1,NumToDWord(lhDocName)+REPL(CHR(0),4)+NumToDWord(lhDocType))=0
		FCLOSE(m.hFile)
		sub_APIError('Error preparing printer for document.')
		RETURN .F.
	ENDIF
	
	* not sure why the PagePrinter calls were commented out, it would seem they're not required
	* but the Windows API documentation calls for them and they don't seem to hamper output
	API_StartPagePrinter(m.hPrinter)

	* copy the file bit by bit
	DO WHILE .NOT.FEOF(m.hFile)
		m.cString=FREAD(m.hFile,1024)
		IF API_WritePrinter(m.hPrinter,m.cString,LEN(m.cString),@m.nWritten)=0
			sub_APIError('Error sending information to printer.')
			EXIT
		ENDIF
	ENDDO
	
	API_EndPagePrinter(m.hPrinter)

	* close the file
	FCLOSE(m.hFile)

	* end the document
	API_EndDocPrinter(m.hPrinter)

	* close the connection to the printer
	API_ClosePrinter(m.hPrinter)

	* deallocate the job name string
	IF VARTYPE(m.lhDocName)='N'
		loHeap.DeAlloc(lhDocName)
	ENDIF 

ENDPROC

PROCEDURE sub_APIError (tcMessage)
	LOCAL lnErrorNo
	m.lnErrorNo=API_GetLastError()
	MESSAGEBOX(;
		IIF(EMPTY(m.tcMessage),ErrorMessage(m.lnErrorNo),m.tcMessage+CHR(13)+ErrorMessage(m.lnErrorNo)),;
		0,"Printing Error (#"+TRAN(m.lnErrorNo)+')')
ENDPROC 



PROCEDURE decl
	DECLARE INTEGER OpenPrinterA IN WINSPOOL.DRV AS API_OpenPrinter ;
		STRING pPrinterName, ;
		INTEGER @phPrinter, ;
		LONG pDefault

	DECLARE LONG StartDocPrinterA IN WINSPOOL.DRV AS API_StartDocPrinter ;
		INTEGER hPrinter, ;
		LONG LEVEL, ;
		STRING pDocInfo

	DECLARE INTEGER EndDocPrinter IN WINSPOOL.DRV AS API_EndDocPrinter ;
		INTEGER hPrinter

	DECLARE INTEGER WritePrinter IN WINSPOOL.DRV AS API_WritePrinter ;
		INTEGER hPrinter, ;
		STRING pBuf, ;
		LONG cbBuf, ;
		LONG @pcWritten

	DECLARE INTEGER ExtEscape IN gdi32.dll AS API_ExtEscape ;
		INTEGER hPrinter,;
		LONG nEscape,;
		LONG nInputLength,;
		STRING cInputBuffer,;
		LONG nOutputLength,;
		STRING cOutputBuffer
		
	DECLARE INTEGER StartPagePrinter IN WINSPOOL.DRV AS API_StartPagePrinter ;
		INTEGER hPrinter

	DECLARE INTEGER EndPagePrinter IN WINSPOOL.DRV AS API_EndPagePrinter ;
		INTEGER hPrinter
		
	DECLARE INTEGER ClosePrinter IN WINSPOOL.DRV AS API_ClosePrinter ;
		INTEGER hPrinter

	DECLARE INTEGER GetLastError IN kernel32 AS API_GetLastError
ENDPROC 