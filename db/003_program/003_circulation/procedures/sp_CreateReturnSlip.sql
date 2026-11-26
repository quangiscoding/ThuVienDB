USE ThuVien2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateReturnSlip
    @StudentID           INT,
    @StaffID             INT,
    @LoanItemID          INT,
    @NewBookStatus       VARCHAR(20)   = 'AVAILABLE',
    @ReturnDate          DATE          = NULL,
    @CustomDamagePercent DECIMAL(5, 2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ReturnDate IS NULL
        SET @ReturnDate = CAST(GETDATE() AS DATE);

    -- =========================================================================
    -- 1. PRE-VALIDATION
    -- =========================================================================
    DECLARE @BookItemID     INT,
            @DueDate        DATE,
            @BookPrice      DECIMAL(18, 2),
            @OwnerStudentID INT;

    SELECT @BookItemID     = li.BookItemID,
           @DueDate        = li.DueDate,
           @BookPrice      = bi.Price,
           @OwnerStudentID = ls.StudentID
    FROM dbo.LoanItem li
    INNER JOIN dbo.LoanSlip ls ON li.LoanSlipID = ls.LoanSlipID
    INNER JOIN dbo.BookItem bi ON li.BookItemID = bi.BookItemID
    WHERE li.LoanItemID = @LoanItemID;

    IF @BookItemID IS NULL
    BEGIN
        THROW 50006, 'LoanItem not found.', 1;
    END

    IF @OwnerStudentID <> @StudentID
    BEGIN
        THROW 50006, 'LoanItem does not belong to the specified student.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.ReturnItem WHERE LoanItemID = @LoanItemID)
    BEGIN
        THROW 50006, 'LoanItem has already been returned.', 1;
    END

    IF @NewBookStatus NOT IN ('AVAILABLE', 'DAMAGED', 'LOST')
       OR NOT EXISTS (SELECT 1 FROM dbo.[Status] WHERE StatusID = @NewBookStatus)
    BEGIN
        THROW 50005, 'Invalid target book status. Allowed values: AVAILABLE, DAMAGED, LOST.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Staff WHERE StaffID = @StaffID)
    BEGIN
        THROW 50001, 'Staff member not found.', 1;
    END

    -- =========================================================================
    -- 2. ATOMIC MUTATION (nested-safe transaction)
    -- =========================================================================
    DECLARE @TranStarted BIT = 0;

    BEGIN TRY
        IF @@TRANCOUNT = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @TranStarted = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION sp_CreateReturnSlip_Inner;
        END

        -- 1. Create ReturnSlip header
        DECLARE @ReturnSlipID INT;
        INSERT INTO dbo.ReturnSlip (StudentID, StaffID, ReturnDate)
        VALUES (@StudentID, @StaffID, @ReturnDate);

        SET @ReturnSlipID = SCOPE_IDENTITY();

        -- 2. Create ReturnItem line
        DECLARE @ReturnItemID INT;
        INSERT INTO dbo.ReturnItem (ReturnSlipID, LoanItemID)
        VALUES (@ReturnSlipID, @LoanItemID);

        SET @ReturnItemID = SCOPE_IDENTITY();

        -- 3. Update physical copy status
        UPDATE dbo.BookItem
        SET StatusID = @NewBookStatus
        WHERE BookItemID = @BookItemID;

        -- 4. Assess LATE fine if returned past DueDate (links to ReturnItemID only)
        IF @ReturnDate > @DueDate
        BEGIN
            DECLARE @DaysOverdue INT = DATEDIFF(DAY, @DueDate, @ReturnDate);
            DECLARE @LateRuleID  INT;

            SELECT TOP 1 @LateRuleID = RuleID
            FROM dbo.FineRule
            WHERE RuleCode = 'LATE';

            IF @LateRuleID IS NOT NULL
            BEGIN
                DECLARE @LateFine DECIMAL(18, 2) = dbo.fn_CalculateFine(@LateRuleID, @DaysOverdue, @BookPrice, NULL);
                IF @LateFine > 0
                BEGIN
                    INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                    VALUES (
                        @LateRuleID,
                        @ReturnItemID,
                        NULL,
                        @LateFine,
                        'UNPAID',
                        N'Overdue return by ' + CAST(@DaysOverdue AS NVARCHAR(10)) + N' day(s)'
                    );
                END
            END
        END

        -- 5. Assess DAMAGED or LOST fine (enforces CK_FineItem_Link XOR constraint)
        IF @NewBookStatus IN ('DAMAGED', 'LOST')
        BEGIN
            DECLARE @ConditionRuleID INT;

            SELECT TOP 1 @ConditionRuleID = RuleID
            FROM dbo.FineRule
            WHERE RuleCode = @NewBookStatus;

            IF @ConditionRuleID IS NOT NULL
            BEGIN
                DECLARE @EffectiveDamagePct DECIMAL(5, 2) =
                    CASE WHEN @NewBookStatus = 'DAMAGED' THEN @CustomDamagePercent ELSE NULL END;

                DECLARE @ConditionFine DECIMAL(18, 2) =
                    dbo.fn_CalculateFine(@ConditionRuleID, 0, @BookPrice, @EffectiveDamagePct);

                IF @ConditionFine > 0
                BEGIN
                    IF @NewBookStatus = 'DAMAGED'
                    BEGIN
                        INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                        VALUES (@ConditionRuleID, @ReturnItemID, NULL, @ConditionFine, 'UNPAID', N'Damaged book penalty');
                    END
                    ELSE -- 'LOST' links directly to LoanItemID (ReturnItemID IS NULL)
                    BEGIN
                        INSERT INTO dbo.FineItem (FineRuleID, ReturnItemID, LoanItemID, Amount, Status, Description)
                        VALUES (@ConditionRuleID, NULL, @LoanItemID, @ConditionFine, 'UNPAID', N'Lost book replacement fine');
                    END
                END
            END
        END

        IF @TranStarted = 1
        BEGIN
            COMMIT TRANSACTION;
        END

        SELECT @ReturnSlipID AS ReturnSlipID,
               @ReturnItemID AS ReturnItemID,
               N'Return slip created successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @TranStarted = 1
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
        END
        ELSE
        BEGIN
            IF XACT_STATE() = 1
                ROLLBACK TRANSACTION sp_CreateReturnSlip_Inner;
        END;

        THROW;
    END CATCH
END;
GO
