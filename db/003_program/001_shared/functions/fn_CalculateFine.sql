USE ThuVien2;
GO

CREATE OR ALTER FUNCTION dbo.fn_CalculateFine (
    @RuleID INT,
    @DaysOverdue INT = 0,
    @BookPrice DECIMAL(18, 2) = 0,
    @CustomDamagePercent DECIMAL(5, 2) = NULL   -- 0.2 = 20%, 0.5 = 50%
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @RatePerDay DECIMAL(18, 2),
            @Percent   DECIMAL(5, 2),
            @FixedFee  DECIMAL(18, 2),
            @RuleCode  VARCHAR(20);

    SELECT  @RatePerDay = ISNULL(RatePerDay, 0),
            @Percent    = ISNULL(PercentOfBookValue, 0),
            @FixedFee   = ISNULL(FixedProcessingFee, 0),
            @RuleCode   = RuleCode
    FROM dbo.FineRule
    WHERE RuleID = @RuleID;

    -- Rule not found -> let the caller see the problem
    IF @RuleCode IS NULL
        RETURN NULL;

    -- Sanitize inputs
    IF @DaysOverdue IS NULL OR @DaysOverdue < 0 
        SET @DaysOverdue = 0;
        
    IF @BookPrice IS NULL 
        SET @BookPrice = 0;

    -- Librarian's manual damage percent: DAMAGED rules only, must be (0, 1]
    IF @CustomDamagePercent IS NOT NULL
       AND @RuleCode = 'DAMAGED'
       AND @CustomDamagePercent > 0 
       AND @CustomDamagePercent <= 1
        SET @Percent = @CustomDamagePercent;

    RETURN (@DaysOverdue * @RatePerDay)
         + (@BookPrice * @Percent)
         + @FixedFee;
END;
GO