const { Pool } = require("pg");
const { PostgresError: PGError } = require("pg-error-enum");

require("dotenv").config();
const path = require("path");
const express = require("express");
const nodeEnv = process.env.NODE_ENV || "development";
const morgan = require("morgan");
const bodyParser = require("body-parser");
const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER || "cr_labeling_admin",
    database: process.env.DB_NAME || "cr_labeling",
    password: process.env.DB_PASS || undefined,
    port: process.env.DB_PORT || 5432,
    max: 5
});

app.use(morgan( nodeEnv === "development" ? "dev" : "combined" ));

app.set("views", "./views");
app.set("view engine", "ejs");

app.use("/", express.static(path.join(__dirname, "public")));

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.get("/", (req, res) => {
    res.redirect(req.baseUrl + "/login");
});

app.get("/login", (_, res) => {
    res.render("login");
});

app.post("/login", async (req, res) => {
    const name = req.body.name;
    let target = `${name}/review`;
    try {
        await pool.query("INSERT INTO reviewer(name) VALUES ($1) RETURNING *", [ name ]);
    } catch ({ code }) {
        if (code !== PGError.UNIQUE_VIOLATION) target = "error";
    } finally {
        res.redirect(`${req.baseUrl}/${target}`);
    }
});

app.get("/:name/review", async (req, res) => {
    const { rows: reviewers } = await pool.query("SELECT * FROM reviewer WHERE name = $1", [ req.params.name ]);
    const { rows: labels } = await pool.query("SELECT * FROM label ORDER BY name");
    res.render("review", {
        reviewer: reviewers[0],
        labels: labels
    });
});

app.post("/label", (req, res) => {
    pool.query("INSERT INTO label(name) VALUES ($1) RETURNING *", [ req.body.name ])
        .then(({ rows }) => { res.status(201).send(rows[0]); })
        .catch(({ code }) => {
            const status = code === PGError.UNIQUE_VIOLATION ? 409 : 500;
            res.status(status).end();
        });
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

app.listen(port, () => {
    if (nodeEnv === "development") {
        console.log(`App listening on: http://localhost:${port}`);
    }
});
