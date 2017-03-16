// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"
import "babel-polyfill"
import "whatwg-fetch"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"



document.getElementById('payload-form').addEventListener('submit', e => {
  e.preventDefault()
  execute.bind(e.target)()
})

const codeTextArea = document.getElementById('payload_code')

async function execute() {
  try {
    const response = await fetch(this.action, {
      method: 'POST',
      body: new FormData(this),
      credentials: 'same-origin'
    })

    if (response.ok) {
      renderOutput(await response.json())
    } else {
      renderError(await response.json())
    }
  } catch (err) {
    console.log(err)
  }
  codeTextArea.value=''
}

const outputTextArea = document.getElementById('output-display');

const renderOutput = json => {
  outputTextArea.innerHTML = json.output
}
const renderError = json => {
  outputTextArea.innerHTML = json.error
}
