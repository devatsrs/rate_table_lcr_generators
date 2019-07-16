DROP PROCEDURE IF EXISTS `prc_InsertIntoRateSearchCode`;
DELIMITER //
CREATE PROCEDURE `prc_InsertIntoRateSearchCode`(
	IN `p_CompanyID` INT
)
BEGIN

		SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

        SET @p_CompanyID                 = p_CompanyID;

        DROP TEMPORARY TABLE IF EXISTS tmp_codedecks;
        CREATE TEMPORARY TABLE tmp_codedecks (
            ID int auto_increment,
            CodeDeckID int,
            primary key (ID)
        );



        SET @v_TerminationType = (SELECT RateTypeID from tblRateType where Slug = 'voicecall');

		insert into tmp_codedecks (CodeDeckID) select CodeDeckID from tblCodeDeck where CompanyID = @p_CompanyID AND Type = @v_TerminationType;

		SET @v_rowCount_ = ( SELECT COUNT(*) FROM tmp_codedecks );
        SET @v_pointer_ = 1;

        WHILE @v_pointer_ <= @v_rowCount_
        DO

			SET @p_codedeckID = ( SELECT CodeDeckID FROM tmp_codedecks WHERE ID = @v_pointer_ );

            DROP TEMPORARY TABLE IF EXISTS tmp_codes;
            CREATE TEMPORARY TABLE tmp_codes (
                ID int auto_increment,
                Code VARCHAR(50),
                primary key (ID)
            );

            insert into tmp_codes ( Code )
            select distinct r.Code from tblRate  r
            left join tblRateSearchCode rsc on r.Code = rsc.RowCode AND r.CodeDeckId = rsc.CodeDeckId  AND rsc.CodeDeckId = @p_codedeckID
            WHERE r.CompanyID = @p_CompanyID and r.CodeDeckId = @p_codedeckID AND rsc.RateSearchCodeID is null;

            select count(*) into @v_row_count from tmp_codes ;

			IF @v_row_count  > 0 THEN

                        
                        SET @v_v_pointer_ = 1;
                        SET @v_limit = 50000;   -- loop of 50 K 
                        SET @v_v_rowCount_ = ceil(@v_row_count/@v_limit) ;

                        WHILE @v_v_pointer_ <= @v_v_rowCount_
                        DO

                            SET @v_OffSet_ = (@v_v_pointer_ * @v_limit) - @v_limit;

                            SET @stm_query = CONCAT("
                                    insert IGNORE into tblRateSearchCode (CompanyID,RowNo, RowCode,Code,CodedeckID)
                                    select ", @p_CompanyID  , " as CompanyID , RowNo,  RowCode , loopCode ,", @p_codedeckID  , " as CodedeckID
                                    from (
                                            select   RowCode , loopCode,
                                            @RowNo := ( CASE WHEN ( @prev_Code = tbl1.RowCode  ) THEN @RowNo + 1
                                                                    ELSE 1
                                                                    END

                                            )      as RowNo,
                                            @prev_Code := tbl1.RowCode
                                            from (
                                                    SELECT distinct f.Code as RowCode, LEFT(f.Code, x.RowNo) as loopCode 
                                                    FROM (
                                                            SELECT @RowNo  := @RowNo + 1 as RowNo
                                                            FROM mysql.help_category
                                                                ,(SELECT @RowNo := 0 ) x
                                                            limit 15
                                                        ) x
                                                        INNER JOIN 
                                                        ( select distinct Code from tmp_codes limit " , @v_limit , "  OFFSET " ,   @v_OffSet_ , "

                                                        ) AS f ON x.RowNo   <= LENGTH(f.Code)
                                                        INNER JOIN tblRate as tr1 on tr1.CodeDeckId = @p_codedeckID AND LEFT(f.Code, x.RowNo) = tr1.Code

                                                    order by RowCode desc,  LENGTH(loopCode) DESC
                                            ) tbl1
                                            , ( Select @RowNo := 0 ) x
                                    ) tbl order by RowCode desc,  LENGTH(loopCode) DESC ;
                                    ");

                        PREPARE stm_query FROM @stm_query;
                        EXECUTE stm_query;
                        DEALLOCATE PREPARE stm_query;

                        SET @v_v_pointer_ = @v_v_pointer_ + 1;

                    END WHILE;

            end if;

            SET @v_pointer_ = @v_pointer_ + 1;

        END WHILE;


		SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

END//
DELIMITER ;