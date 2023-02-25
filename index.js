const { Pool } = require("pg");
const { PostgresError: PGError } = require("pg-error-enum");
const { parse: parsePGArray } = require("postgres-array");
const { Server: IO } = require("socket.io");

require("dotenv").config();
const path = require("path");
const express = require("express");
const paginate = require("express-paginate");
const nodeEnv = process.env.NODE_ENV || "development";
const morgan = require("morgan");
const bodyParser = require("body-parser");
const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({
    host: process.env.DATABASE_HOST || "localhost",
    user: process.env.DATABASE_USER || "cr_labeling_admin",
    database: process.env.DATABASE_NAME || "cr_labeling",
    password: process.env.DATABASE_PASS || undefined,
    port: process.env.DATABASE_PORT || 5432,
    max: 5
});

app.use(morgan( nodeEnv === "development" ? "dev" : "combined" ));

app.set("views", "./views");
app.set("view engine", "ejs");

app.use("/", express.static(path.join(__dirname, "public")));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.use(paginate.middleware(10, 50));

app.get("/", (req, res) => {
    res.redirect(`${req.baseUrl}/login`);
});

app.get("/login", async (_, res) => {
    const { rows: reviewers } = await pool.query("SELECT * FROM reviewer");
    res.render("login", { reviewers: reviewers });
});

app.post("/login", async (req, res) => {
    const { rows: [ reviewer ] } = await pool.query(
        "SELECT * FROM reviewer WHERE id = $1 LIMIT 1",
        [ req.body.id ]
    );
    const target = (reviewer)
        ? `${req.baseUrl}/${reviewer.name}/queue`
        : `${req.baseUrl}/login`;
    res.redirect(target);
});

app.get("/:name/queue", async (req, res) => {
    const { rows: labels } = await pool.query("SELECT * FROM label ORDER BY name");
    const { rows: [ reviewer ] } = await pool.query(
        "SELECT * FROM instance_review_progress WHERE name = $1 LIMIT 1",
        [ req.params.name ]
    );
    const { rows: [ instance ] } = await pool.query(
        "SELECT * FROM next_instance($1)",
        [ reviewer?.id || null ]
    );
    res.render("review", {
        reviewer: reviewer,
        instance: instance,
        labels: labels
    });
});

app.get("/progress", async (req, res) => {
    const { rows: buckets } = await pool.query("SELECT * FROM instance_review_bucket");
    const { rows: reviewers } = await pool.query("SELECT * FROM instance_review_progress");
    res.render("progress", {
        buckets: buckets,
        reviewers: reviewers
    });
});

app.post("/instance/submit", async (req, res) => {
    const payload = req.body;
    const parameters = [
        payload.instance_id,
        payload.reviewer_id,
        payload.is_interesting,
        payload.invert_category,
        payload.remarks
    ];

    const { rows: [ { id: instance_review_id } ] } = await pool.query(
        `INSERT INTO instance_review(instance_id, reviewer_id, is_interesting, invert_category, remarks) 
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        parameters
    );

    payload.label_ids.forEach(label_id => {
        pool.query(
            "INSERT INTO instance_review_label(label_id, instance_review_id) VALUES ($1, $2)",
            [ label_id, instance_review_id ]
        );
    });

    res.status(200).end();
});

app.post("/instance/discard", (req, res) => {
    const payload = req.body;
    const parameters = [ payload.instance_id, payload.reviewer_id, payload.remarks ];
    pool.query(
        `INSERT INTO instance_discard(instance_id, reviewer_id, remarks)
         VALUES ($1, $2, $3)`,
        parameters
    ).then(() => res.status(200).end());
});

app.get("/label", async (_, res) => {
    const { rows: labels } = await pool.query("SELECT * FROM label ORDER BY name");
    res.status(200).send(labels);
});

app.post("/label", (req, res) => {
    pool.query("INSERT INTO label(name) VALUES ($1) RETURNING *", [ req.body.name ])
        .then(({ rows }) => { res.status(201).send(rows[0]); })
        .catch(({ code }) => {
            const status = code === PGError.UNIQUE_VIOLATION ? 409 : 500;
            res.status(status).end();
        });
});

app.get("/conflicts", async (req, res) => {
    const current = req.query.page || 1;
    const limit = req.query.limit || 10;
    const id = req.query.id || 1;
    const order = (id > 0) ? "ASC" : "DESC";
    const query =
        `SELECT id
         FROM instance_review_conflict
         ORDER BY id ${order}
         OFFSET $1
         LIMIT $2`;
    const { rows: conflicts } = await pool.query(query, [ (current - 1) * limit, limit ]);
    const { rows: [ { count: items } ] } = await pool.query(
        "SELECT COUNT(id) FROM instance_review_conflict"
    );
    const pages = Math.ceil(items / req.query.limit);
    res.render("conflicts", {
        conflicts: conflicts,
        pagination: {
            items: items,
            pages: pages,
            current: current,
            limit: limit,
            id: id
        }
    });
});

app.get("/conflicts/:id", async (req, res) => {
    const params = [ req.params.id ];
    const { rows: [ instance ] } = await pool.query("SELECT * FROM instance_review_conflict WHERE id = $1", params);
    if (!instance) {
        res.render("error", {
            icon: "bi-none",
            title: "Conflict not found or already resolved!"
        });
    }
    instance.conflicts = parsePGArray(instance.conflicts);
    const { rows: reviews } = await pool.query("SELECT * FROM instance_review_details($1)", params);
    const { rows: discards } = await pool.query("SELECT * FROM instance_discard_details($1)", params);
    const { rows: labels } = await pool.query("SELECT * FROM label ORDER BY name");
    res.render("conflict", {
        instance: instance,
        reviews: reviews,
        discards: discards,
        labels: labels
    });
});

app.post("/conflicts/:id/review", (req, res) => {
    const params = [
        req.params.id,
        req.body.conflicts,
        req.body.label_ids,
        req.body.is_interesting,
        req.body.invert_category,
        req.body.remarks
    ];
    pool.query("CALL conflict_resolution_review($1, $2, $3, $4, $5, $6)", params)
        .then(() => res.status(201).end());
});

app.post("/conflicts/:id/discard", (req, res) => {
    const params = [
        req.params.id,
        req.body.conflicts,
        req.body.remarks
    ];
    pool.query("CALL conflict_resolution_discard($1, $2, $3)", params)
        .then(() => res.status(201).end());
});

app.get("/error", (_, res) => {
    res.render("error");
});

app.get("*", (_, res) => {
    res.render("error", {
        icon: "bi-emoji-dizzy-fill",
        title: "Page Not Found!"
    });
});

const server = app.listen(port, () => {
    if (nodeEnv === "development") {
        console.log(`App listening on: http://localhost:${port}`);
    }
});

const io = new IO(server);

io.on("connection", (socket) => {
    socket.on("label_added", (label) => {
        socket.broadcast.emit("label_append", label);
    });
});
