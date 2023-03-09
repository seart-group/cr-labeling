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
    "conflict_resolution_discard"(
        instance_id integer,
        conflicts conflict[],
        remarks text
    )
AS $$
    DECLARE
        _instance_id integer;
        _conflict conflict;
        _conflicts conflict[];
        _remarks text;
        _reviewer integer;
        _reviewers integer[];
    BEGIN
        -- Copy parameters to avoid ambiguity
        _instance_id := conflict_resolution_discard.instance_id;
        _conflicts := conflict_resolution_discard.conflicts;
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
        -- Record conflict resolution
        FOREACH _conflict IN ARRAY _conflicts
        LOOP
            INSERT INTO instance_review_conflict_resolution(instance_id, conflict)
            VALUES (_instance_id, _conflict);
        END LOOP;
    END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE PROCEDURE
    "conflict_resolution_review"(
        instance_id integer,
        conflicts conflict[],
        label_ids integer[],
        is_interesting boolean,
        invert_category boolean,
        remarks text
    )
AS $$
    DECLARE
        _instance_id integer;
        _conflict conflict;
        _conflicts conflict[];
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
        _conflicts := conflict_resolution_review.conflicts;
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
        -- Record conflict resolution
        FOREACH _conflict IN ARRAY _conflicts
        LOOP
            INSERT INTO instance_review_conflict_resolution(instance_id, conflict)
            VALUES (_instance_id, _conflict);
        END LOOP;
    END;
$$ LANGUAGE PLpgSQL;

CREATE OR REPLACE PROCEDURE "export_csv"()
AS $$
    -- Export reviews with all information
    COPY (
        SELECT
            finished.id AS id,
            finished.task AS task,
            finished.work AS work,
            finished.category AS category,
            finished.input_code AS input_code,
            finished.input_nl AS input_nl,
            finished.output AS output,
            finished.target AS target,
            STRING_AGG(
                DISTINCT label.name,
                ',' ORDER BY label.name
            ) AS labels,
            STRING_AGG(
                DISTINCT review.remarks,
                ',' ORDER BY review.remarks
            ) AS remarks,
            BOOL_OR(review.is_interesting) AS is_interesting
        FROM instance_review_finished AS finished
        INNER JOIN instance_review review
            ON finished.id = review.instance_id
        INNER JOIN instance_review_label review_label
            ON review.id = review_label.instance_review_id
        INNER JOIN label
            ON label.id = review_label.label_id
        GROUP BY
            finished.id,
            finished.task,
            finished.work,
            finished.category,
            finished.input_code,
            finished.input_nl,
            finished.output,
            finished.target
    ) TO '/tmp/instance_review.csv' WITH CSV DELIMITER ',' HEADER;
    -- Export discards with all information
    COPY (
        SELECT
            instance.*,
            STRING_AGG(
                DISTINCT discard.remarks,
                ',' ORDER BY discard.remarks
            ) AS remarks
        FROM instance
        INNER JOIN instance_discard AS discard
            ON instance.id = discard.instance_id
        GROUP BY instance.id
    ) TO '/tmp/instance_discard.csv' WITH CSV DELIMITER ',' HEADER;
    -- Export resolved conflicts
    COPY (
        SELECT
            resolution.instance_id AS instance_id,
            STRING_AGG(
                resolution.conflict::text, ','
            ) AS conflicts
        FROM instance_review_conflict_resolution AS resolution
        GROUP BY resolution.instance_id
    ) TO '/tmp/instance_review_conflict_resolution.csv' WITH CSV DELIMITER ',' HEADER;
$$ LANGUAGE SQL;
