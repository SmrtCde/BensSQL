-- List of procedures you want to analyze
DECLARE @Procedures TABLE
(ProcName SYSNAME)
;

INSERT INTO @Procedures (ProcName)
VALUES
    ('dbo.usp_ProcedureA'),
    ('dbo.usp_ProcedureB'),
    ('dbo.usp_ProcedureC'),
    ('dbo.usp_ProcedureD');
;

-- Find dependencies between procedures in the list
SELECT
	OBJECT_SCHEMA_NAME(d.referencing_id) + '.' + OBJECT_NAME(d.referencing_id) AS ReferencingProcedure
	,OBJECT_SCHEMA_NAME(d.referenced_id) + '.' + OBJECT_NAME(d.referenced_id) AS ReferencedProcedure

FROM
	sys.sql_expression_dependencies d

WHERE
	d.referencing_id IN (
		SELECT OBJECT_ID(ProcName)
		FROM @Procedures
	)
	AND d.referenced_id IN (
		SELECT OBJECT_ID(ProcName)
		FROM @Procedures
	)

ORDER BY
	ReferencingProcedure
	,ReferencedProcedure
;
