require("dotenv").config();
const express = require("express");
const bodyParser = require("body-parser");
const app = express();
const port = process.env.PORT || 3000;

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.get("/", function (req, res) {
    res.send("Hello World");
});

app.post("/login", function (req, res) {
    const name = req.body.name;
    res.status(200);
    res.send(`Logged in as: ${name}`);
});

app.listen(port);
