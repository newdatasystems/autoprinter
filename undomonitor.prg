LPARAMETERS tcValue,tnSelStart
RETURN CREATEOBJECT('UndoMonitor',tcValue,tnSelStart)

DEFINE CLASS UndoMonitor AS Exception
	PROTECTED aUndoBuffer[1],aRedoBuffer[1],nUndoCount,nRedoCount,nLastUpdate,bNoProgrammaticChange,bBackSpacing

	aUndoBuffer = .f.
	aRedoBuffer = .f.
	nUndoCount = 0
	nRedoCount = 0
	
	nUndoMax = 50
	nInitialBuffer = 10
	
	bNoProgrammaticChange = .f.
	nLastUndoUpdate = 0
	bBackspacing = .f.

	cInitialValue = ''
	nInitialSelStart = 0
	bInitialized = .f.
	
	cValue = ''
	nSelStart = 0
	
	PROCEDURE Init (tcValue,tnSelStart)
		DIMENSION this.aUndoBuffer[this.nInitialBuffer,2]
		DIMENSION this.aRedoBuffer[CEIL(this.nInitialBuffer/2),2]
		IF VARTYPE(tcValue)='C'
			this.Reset(tcValue,EVL(tnSelStart,0))
		ENDIF
	ENDPROC
	
	PROCEDURE Reset (tcValue,tnSelStart)
		this.bInitialized = .t.
		this.cInitialValue = tcValue
		this.nInitialSelStart = tnSelStart
		this.cValue = tcValue
		this.nSelStart = tnSelStart
		store .f. to this.aUndoBuffer,this.aRedoBuffer
		this.nUndoCount = 0
		this.nRedoCount = 0
	ENDPROC
	
	PROCEDURE InteractiveChange (tcValue,tnSelStart)
		this.bInitialized = .t.

		LOCAL lnKeyCode,lbBackSpace
		lnKeyCode = LASTKEY()
		lbBackSpace = (lnKeyCode = 127)
		
		IF ( this.bBackSpacing # lbBackSpace ) OR;
			( !lbBackSpace AND SECONDS() - this.nLastUndoUpdate > .5 AND INLIST(lnKeyCode,32,13,44,46,9) )
			this.AddUndoFrame(this.cValue,this.nSelStart)
			this.nRedoCount = 0
		ENDIF

		this.cValue = tcValue
		this.nSelStart = tnSelStart
		this.bBackSpacing = lbBackSpace
		this.nLastUndoUpdate = SECONDS()		
	ENDPROC
	
	PROCEDURE ProgrammaticChange (tcValue,tnSelStart)
		IF this.bNoProgrammaticChange
			RETURN
		ENDIF
		
		IF NOT this.bInitialized
			this.cInitialValue = tcValue
			this.nInitialSelStart = tnSelStart
			this.bInitialized = .t.
		ENDIF
		
		this.AddUndoFrame(tcValue,tnSelStart)
		this.cValue = tcValue
		this.nSelStart = tnSelStart

		this.nRedoCount = 0
	ENDPROC
	
	PROTECTED PROCEDURE AddRedoFrame (tcValue,tnSelStart)
		IF this.nRedoCount = this.nUndoMax
			* delete the row in the buffer (which brings everything down and clear the last entry)
			ADEL(this.aRedoBuffer,1)
		ELSE
			this.nRedoCount = this.nRedoCount + 1
		ENDIF
		IF ALEN(this.aRedoBuffer,1) < this.nRedoCount
			DIMENSION this.aRedoBuffer[this.nRedoCount + 5, 2]
		ENDIF
		this.aRedoBuffer[this.nRedoCount,1] = tcValue
		this.aRedoBuffer[this.nRedoCount,2] = tnSelStart		
	ENDPROC
	
	PROTECTED PROCEDURE AddUndoFrame (tcValue,tnSelStart)
		IF this.nUndoCount == this.nUndoMax
			* delete the row in the buffer (which brings everything down and clear the last entry)
			ADEL(this.aUndoBuffer,1)
		ELSE
			this.nUndoCount = this.nUndoCount + 1
		ENDIF
		IF ALEN(this.aUndoBuffer,1) < this.nUndoCount
			DIMENSION this.aUndoBuffer[this.nUndoCount + 3, 2]
		ENDIF
		this.aUndoBuffer[this.nUndoCount,1] = tcValue
		this.aUndoBuffer[this.nUndoCount,2] = tnSelStart
	ENDPROC
	
	PROTECTED PROCEDURE UpdateUndoFrame (tcValue,tnSelStart)
		IF this.nUndoCount == 0
			this.AddUndoFrame(tcValue, tnSelStart)
		ELSE
			this.aUndoBuffer[this.nUndoCount,1] = tcValue
			this.aUndoBuffer[this.nUndoCount,2] = tnSelStart
		ENDIF
	ENDPROC
	
	PROCEDURE CanUndo
		RETURN this.nUndoCount > 0 OR !(this.cInitialValue == this.cValue)
	ENDPROC
	
	PROCEDURE CanRedo
		RETURN this.nRedoCount > 0
	ENDPROC
	
	PROCEDURE Undo
		LOCAL lbNoProg
		lbNoProg = this.bNoProgrammaticChange 
		this.bNoProgrammaticChange = .T.
		IF this.nUndoCount > 0
				  
			this.AddRedoFrame(this.cValue,this.nSelStart)

			lcValue = this.aUndoBuffer[this.nUndoCount,1]
			IF lcValue = this.cValue AND this.nUndoCount > 1
				this.cValue = this.aUndoBuffer[this.nUndoCount-1, 1]
				this.nUndoCount = this.nUndoCount - 1
			ELSE
				this.cValue = lcValue
			ENDIF
			this.nSelStart = this.aUndoBuffer[this.nUndoCount,2]

			this.nUndoCount = this.nUndoCount - 1
		ELSE
			* no new values, so return to the initial value
			this.cValue = this.cInitialValue
			this.nSelStart = this.nInitialSelStart		
		ENDIF
				
		this.UpdateValue(this.cValue,this.nSelStart)		
		this.bNoProgrammaticChange = lbNoProg
	ENDPROC
	
	PROCEDURE Redo
		IF this.nRedoCount > 0
			LOCAL lbNoProg
			lbNoProg = this.bNoProgrammaticChange
			this.bNoProgrammaticChange = .t.
			
			this.AddUndoFrame(this.cValue,this.nSelStart)
			
			this.cValue = this.aRedoBuffer[this.nRedoCount,1]
			this.nSelStart = this.aRedoBuffer[this.nRedoCount,2]
			this.nRedoCount = this.nRedoCount - 1
			
			this.UpdateValue(this.cValue,this.nSelStart)

			this.bNoProgrammaticChange = lbNoProg			
		ENDIF 
	ENDPROC
	
	* the calling object should bind to this method to be notified when the undo or redo events have updated
	PROCEDURE UpdateValue (tcValue, tnSelStart)
	
	ENDPROC
	
ENDDEFINE
