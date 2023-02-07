CREATE OR REPLACE VIEW "instance_review_finished" AS
SELECT instance.*
FROM instance INNER JOIN instance_review ir on instance.id = ir.instance_id
GROUP BY instance.id
HAVING COUNT(instance.id) > 1;

CREATE OR REPLACE VIEW "instance_review_buckets" AS
SELECT instance.task AS task, instance.work AS work, instance.category AS category, COUNT(instance.id) AS count
FROM instance INNER JOIN instance_review ir ON instance.id = ir.instance_id
GROUP BY instance.task, instance.work, instance.category
ORDER BY instance.task, instance.work, instance.category;

CREATE OR REPLACE VIEW "instance_review_buckets_filled" AS
SELECT buckets.task, buckets.work, buckets.category
FROM instance_review_buckets AS buckets
WHERE buckets.count > 166;

CREATE OR REPLACE FUNCTION
    "next_instance"(reviewer_id integer)
    RETURNS SETOF instance
AS $$
    SELECT instance.* FROM instance
    LEFT OUTER JOIN instance_discard AS discarded ON instance.id = discarded.instance_id
    LEFT OUTER JOIN instance_review AS review ON instance.id = review.instance_id
    LEFT OUTER JOIN instance_review_finished AS finished ON instance.id = finished.id
    -- Ignore instances that were:
    -- * reviewed more than twice
    -- * already reviewed by reviewer
    -- * already discarded by reviewer
    -- * whose (task, work, category) triplet
    --   has passed bucket threshold
    WHERE
        finished.id IS NULL
    AND
        review.reviewer_id IS DISTINCT FROM next_instance.reviewer_id
    AND
        discarded.reviewer_id IS DISTINCT FROM next_instance.reviewer_id
    AND
        (instance.task, instance.work, instance.category) NOT IN (SELECT * FROM instance_review_buckets_filled)
    -- Discarded instances are given priority
    -- Other instances will be sorted randomly
    ORDER BY discarded.reviewer_id DESC NULLS LAST, RANDOM()
    LIMIT 1
;
$$ LANGUAGE SQL;
