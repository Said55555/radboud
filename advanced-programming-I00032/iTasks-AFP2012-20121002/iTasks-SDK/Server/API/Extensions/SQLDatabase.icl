implementation module SQLDatabase

import iTasks, SQL, MySQL, Error, IWorld, Shared

derive class iTask SQLValue, SQLDate, SQLTime

sqlExecute	:: SQLDatabase SQLStatement ![SQLValue] -> Task [SQLRow]
sqlExecute db query values = mkInstantTask "SQL Execute" exec
where
	exec _ iworld=:{IWorld|world}
		# (mbOpen,world)	= openMySQLDb db world
		= case mbOpen of
			Error e			= (taskException e,  {IWorld|iworld & world = world})
			Ok (cur,con,cxt)
				# (err,cur)			= execute query values cur
				| isJust err		= (taskException (toString (fromJust err)),{IWorld|iworld & world = world})
				# (err,rows,cur)	= fetchAll cur
				| isJust err		= (taskException (toString (fromJust err)),{IWorld|iworld & world = world})
				# world				= closeMySQLDb cur con cxt world
				= (TaskFinished rows,{IWorld|iworld & world = world})

sqlShare :: SQLDatabase SQLStatement ![SQLValue] -> ReadOnlyShared [SQLRow] 
sqlShare db query values = makeReadOnlySharedError ("mysql-" +++ db.SQLDatabase.database) read time
where
	read iworld=:{IWorld|world}
		# (mbOpen,world) = openMySQLDb db world
		= case mbOpen of
			Error e			= (Error e,  {IWorld|iworld & world = world})
			Ok (cur,con,cxt)
				# (err,cur)			= execute query values cur
				| isJust err		= (Error (toString (fromJust err)),{IWorld|iworld & world = world})
				# (err,rows,cur)	= fetchAll cur
				| isJust err		= (Error (toString (fromJust err)),{IWorld|iworld & world = world})
				# world				= closeMySQLDb cur con cxt world
				= (Ok rows,{IWorld|iworld & world = world})
		
	time iworld=:{IWorld|timestamp}
		= (Ok timestamp,iworld)

openMySQLDb :: !SQLDatabase !*World -> (MaybeErrorString (!*MySQLCursor, !*MySQLConnection, !*MySQLContext), !*World)
openMySQLDb db world
	# (err,mbContext,world) 	= openContext world
	| isJust err				= (Error (toString (fromJust err)),world)
	# (err,mbConn,context)		= openConnection db (fromJust mbContext)
	| isJust err				= (Error (toString (fromJust err)),world)
	# (err,mbCursor,connection)	= openCursor (fromJust mbConn)
	| isJust err				= (Error (toString (fromJust err)),world)
	= (Ok (fromJust mbCursor,connection, context), world)
				
closeMySQLDb :: !*MySQLCursor !*MySQLConnection !*MySQLContext !*World -> *World
closeMySQLDb cursor connection context world
	# (err,connection)	= closeCursor cursor connection
	# (err,context) 	= closeConnection connection context
	# (err,world)		= closeContext context world
	= world
