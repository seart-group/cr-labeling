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
    "conflict_resolution_discard"(instance_id integer, remarks text)
AS $$
    DECLARE
        _instance_id integer;
        _remarks text;
        _reviewer integer;
        _reviewers integer[];
    BEGIN
        -- Copy parameters to avoid ambiguity
        _instance_id := conflict_resolution_discard.instance_id;
        _remarks := conflict_resolution_discard.remarks;
        -- Record reviewers that have already reviewed the instance
        SELECT ARRAY_AGG(reviewer_id) INTO _reviewers
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
        FOREACH _reviewer IN ARRAY _reviewers
        LOOP
            INSERT INTO instance_discard(instance_id, reviewer_id, remarks)
            VALUES (_instance_id, _reviewer, _remarks);
        END LOOP;
        -- Update existing instance discards with the provided remarks
        UPDATE instance_discard AS discard
        SET remarks = _remarks
        WHERE discard.instance_id = _instance_id;
    END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE PROCEDURE
    "conflict_resolution_review"(
    instance_id integer,
    label_ids integer[],
    is_interesting boolean,
    invert_category boolean,
    remarks text
)
AS $$
    DECLARE
        _instance_id integer;
        _label_id integer;
        _label_ids integer[];
        _review_id integer;
        _is_interesting boolean;
        _invert_category boolean;
        _remarks text;
        _person integer;
        _reviewers integer[];
        _discarders integer[];
    BEGIN
        -- Copy parameters to avoid ambiguity
        _instance_id := conflict_resolution_review.instance_id;
        _label_ids := conflict_resolution_review.label_ids;
        _is_interesting := conflict_resolution_review.is_interesting;
        _invert_category := conflict_resolution_review.invert_category;
        _remarks := conflict_resolution_review.remarks;
        -- Record reviewers that have already reviewed the instance
        SELECT ARRAY_AGG(reviewer_id) INTO _reviewers
        FROM instance_review review
        WHERE review.instance_id = _instance_id;
        -- Record discarders that have already discarded the instance
        SELECT ARRAY_AGG(reviewer_id) INTO _discarders
        FROM instance_discard discard
        WHERE discard.instance_id = _instance_id;
        -- Clean discards, labels and reviews related to the instance
        DELETE FROM instance_discard discard WHERE discard.instance_id = _instance_id;
        DELETE FROM instance_review_label WHERE instance_review_id IN (
            SELECT id
            FROM instance_review review
            WHERE review.instance_id = _instance_id
        );
        DELETE FROM instance_review review WHERE review.instance_id = _instance_id;
        -- Add a review with provided labels for each reviewer and discarder
        FOREACH _person IN ARRAY ARRAY_CAT(_reviewers, _discarders)
        LOOP
            INSERT INTO instance_review(instance_id, reviewer_id, is_interesting, invert_category, remarks)
            VALUES (_instance_id, _person, _is_interesting, _invert_category, _remarks)
            RETURNING id INTO _review_id;
            FOREACH _label_id IN ARRAY _label_ids
            LOOP
                INSERT INTO instance_review_label(instance_review_id, label_id)
                VALUES (_review_id, _label_id);
            END LOOP;
        END LOOP;
    END;
$$ LANGUAGE PLpgSQL;
