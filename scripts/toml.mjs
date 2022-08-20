#!/usr/local/bin/node
import * as gleam from '../build/dev/javascript/parser_gleam/dist/parser_gleam.mjs'
import * as fs from 'fs'


var stdinBuffer = fs.readFileSync(0); // STDIN_FILENO = 0
const file = stdinBuffer.toString()
const result = gleam.toml_to_json(file)
if (result.isOk()) {
    process.stdout.write(result[0]);
} else {
    console.error(result[0])
    throw new Error('had error')
}