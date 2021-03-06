# Audience Frontend Integration Library

This is the frontend integration library of Audience.

You will find further information on [github.com/coreprocess/audience](https://github.com/coreprocess/audience).

## Example

```ts
import 'audience-frontend';
import { Chart } from 'chart.js';
import { Notyf } from 'notyf';
import 'notyf/notyf.min.css';

var notyf = new Notyf();

var ctx = document.getElementById('chart');
var chart = new Chart(ctx, { /* -- snip -- */ });

window.audience.onMessage(function (message) {
  message = JSON.parse(message);
  if (message.timestamp !== undefined && message.roundtrip !== undefined) {
    chart.options.scales.xAxes[0].ticks.min = message.timestamp - 30 * 1000;
    chart.options.scales.xAxes[0].ticks.max = message.timestamp + 0 * 1000;
    chart.data.datasets[0].data.push({
      x: new Date(message.timestamp),
      y: message.roundtrip
    });
    chart.update();
  }
  if (message.error) {
    notyf.error(message.error);
  }
});

document.addEventListener('keydown', function (event) {
  if (event.key === "Escape" || event.key === "Esc") {
    window.audience.postMessage('close');
  }
});
```

See [here](https://github.com/coreprocess/audience/tree/master/examples/ping) and [here](https://github.com/coreprocess/audience/tree/master/examples/terminal) for complete examples.

## What is Audience?
A small adaptive cross-platform and cross-technology webview window library to build modern cross-platform user interfaces.

- It is **small**: The size of the Audience runtime is just a fraction of the size of the Electron runtime. Currently, the ratio is about 1%, further optimizations pending.

- It is **compatible**: Currently, we provide ready-to-go APIs for C/C++ and Node.js, but you can plug it into any environment, which supports either C bindings or can talk to Unix sockets respectively named pipes.

- It is **adaptive**: Audience adapts to its environment using the best available webview technology based on a priority list. E.g., on Windows, it can be configured to try embedding of EdgeHTML first and fall back to the embedding of IE11.

- It supports two-way **messaging**: the web app can post messages to the native backend, and the native backend can post messages to the web app.

- It supports web apps provided via a filesystem folder or URL. Audience provides its custom web server and websocket service tightly integrated into the library. But if you prefer a regular http URL schema, you can use Express or any other http based framework you like.

- The core provides a lightweight C API, a command-line interface, as well as a channel-based API (using Unix sockets and named pipes on Windows). Integrations into other environments are provided on top, e.g., for Node.js.

## Authors and Contributors

Authored and maintained by Niklas Salmoukas [[@GitHub](https://github.com/coreprocess) [@LinkedIn](https://www.linkedin.com/in/salmoukas/) [@Xing](https://www.xing.com/profile/Niklas_Salmoukas) [@Twitter](https://twitter.com/salmoukas) [@Facebook](https://www.facebook.com/salmoukas) [@Instagram](https://www.instagram.com/salmoukas/)].

[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/0)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/0)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/1)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/1)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/2)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/2)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/3)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/3)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/4)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/4)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/5)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/5)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/6)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/6)[![](https://sourcerer.io/fame/coreprocess/coreprocess/audience/images/7)](https://sourcerer.io/fame/coreprocess/coreprocess/audience/links/7)
