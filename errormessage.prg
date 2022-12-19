PARAMETERS tnErrno,taArgs

#DEFINE FORMAT_MESSAGE_FROM_SYSTEM 0x00001000

DECLARE INTEGER FormatMessage IN kernel32 AS API_FormatMessage ;
	INTEGER   dwFlags,;
	STRING  @ lpSource,;
	INTEGER   dwMessageId,;
	INTEGER   dwLanguageId,;
	STRING  @ lpBuffer,;
	INTEGER   nSize,;
	INTEGER   Arguments

DECLARE INTEGER GetLastError IN kernel32 AS API_GetLastError

LOCAL lnCount,lcBuff,loHeap,lnAlloc,lcResult

if vartype(tnErrNo)#'N'
	tnErrNo=API_GetLastError()
endif

lcBuff=SPACE(128)
lnCount=API_FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,;
	'winerror.h',tnErrno,0,@lcBuff,128,0)

if lnCount>0
	lcResult=LEFT(lcBuff,AT(CHR(0),lcBuff)-1)
else
	lcResult='('+errormessage(API_GetLastError())+')'
endif

return lcResult