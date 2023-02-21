CREATE OR REPLACE PROCEDURE
    "rename_label"(old_name text, new_name text)
AS $$
BEGIN
    IF
        old_name IS NULL
    OR
        new_name IS NULL
    THEN
        RAISE EXCEPTION 'The name parameters are required!';
    END IF;
    UPDATE label
    SET name = new_name
    WHERE name = old_name;
END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE PROCEDURE
    "discard_reviewed_instances"(instance_id integer, remarks text)
AS $$
    DECLARE
        _instance_id integer;
        _remarks text;
        reviewer integer;
        reviewers integer[];
    BEGIN
        -- Copy parameters to avoid ambiguity
        _instance_id := discard_reviewed_instances.instance_id;
        _remarks := discard_reviewed_instances.remarks;
        -- Record reviewers that have already reviewed the instance
        SELECT ARRAY_AGG(reviewer_id) INTO reviewers
        FROM instance_review review
        WHERE review.instance_id = _instance_id;
        -- Clean labels and reviews related to the instance
        DELETE FROM instance_review_label WHERE instance_review_id IN (
            SELECT id
            FROM instance_review review
            WHERE review.instance_id = _instance_id
        );
        DELETE FROM instance_review review WHERE review.instance_id = _instance_id;
        -- Add a discard entry for each previous reviewer
        FOREACH reviewer IN ARRAY reviewers
        LOOP
            INSERT INTO instance_discard(instance_id, reviewer_id, remarks)
            VALUES (_instance_id, reviewer, _remarks);
        END LOOP;
        -- Update existing instance discards with the provided remarks
        UPDATE instance_discard AS discard
        SET remarks = _remarks
        WHERE discard.instance_id = _instance_id;
    END;
$$ LANGUAGE PLpgSQL;
