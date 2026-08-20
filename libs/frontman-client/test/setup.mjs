import {Worker as NodeWorker} from 'node:worker_threads'

globalThis.Worker = class Worker {
  constructor(url) {
    const source = `
      import {parentPort, workerData} from 'node:worker_threads'
      globalThis.self = {
        onmessage: undefined,
        postMessage: value => parentPort.postMessage(value),
      }
      parentPort.on('message', data => globalThis.self.onmessage({data}))
      await import(workerData.url)
    `
    this.worker = new NodeWorker(source, {eval: true, workerData: {url: url.href}})
    this.worker.on('message', data => this.onmessage?.({data}))
    this.worker.on('error', error => this.onerror?.({message: error.message}))
  }

  postMessage(value) {
    this.worker.postMessage(value)
  }

  terminate() {
    void this.worker.terminate()
  }
}
