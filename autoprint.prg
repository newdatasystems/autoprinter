PROCEDURE AutoPrint
	PARAMETERS tuParam1,tuParam2,tuParam3
	application.Visible = .f.
	SET RESOURCE OFF 

	LOCAL lcSavePrinter,lcSaveDirectory,lcSaveUserID,lcSaveCompany
	LOCAL lcDataFile,lcOldSafety
	PRIVATE poDataObj

	poDataObj = .f.
	lnAt = AT(' ',SYS(16),2)
	lcDataFile = ADDBS(JUSTPATH(SUBSTR(SYS(16),lnAt+1)))
	lcDataFile = lcDataFile+'AutoPrint.mem'

	IF FILE(lcDataFile)
		RESTORE FROM (lcDataFile) ADDITIVE 

		poDataObj = CREATEOBJECT('custom')
		IF VARTYPE(poDataObj)='O'
			poDataObj.addproperty('UserID',lcSaveUserID)
			poDataObj.addproperty('Directory',lcSaveDirectory)
			poDataObj.addproperty('Printer',lcSavePrinter)
			poDataObj.addproperty('Company',lcSaveCompany)
		ENDIF 	
	ENDIF 
		
	DO FORM AutoPrint
	READ EVENTS

	_Screen.WindowState = 1 && Minimize the window

	IF VARTYPE(poDataObj)='O'
		lcSaveUserID = poDataObj.UserID
		lcSaveDirectory = poDataObj.Directory
		lcSavePrinter = poDataObj.Printer
		lcSaveCompany = poDataObj.Company
		lcOldSafety = SET("Safety")
		SET SAFETY OFF
		SAVE to (lcDataFile) ALL LIKE 'lcSave*'
		SET SAFETY &lcOldSafety
	ENDIF 
ENDPROC 