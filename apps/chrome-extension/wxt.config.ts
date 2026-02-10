import { defineConfig } from 'wxt';

// See https://wxt.dev/api/config.html
export default defineConfig({
  manifest: {
    //kfdpjbmabcelpgoipaccjijhehdmeghp
    key: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5ucRZpSZ9epesfagtLnNDsiLwh5WwFwJeMjgqxwsVnQ6jnrDFoRxMpBaPNUraRpmZtbYhjm5nk7odvhp+jcoyiln3iBnf7ri8YQ/XFRE6CqLC8+xXbURuZL+MkVeyfJ8mrsDhaAp64Vmu2C9EQROXA+7Rg5xkCxL1UxSWPweFyeh7yUwNlaCZvMYTLXOPnLwI+xipcvOYIjd56PEDT8CFuTsfngB5Y87+pVKAdaRlkqgCrWI8ZHbk9Q0Vxt3FTRprEJ7U+W/hngHIuUedlfpZlN+6Qo0nSY6LrEZ86Ly94ZiEOpz0tm2Z35fCFbGknV4lmEXFvX795CXZ+j2Laqu5QIDAQAB",
    externally_connectable: {
      ids: ['*'],
      matches: ["http://localhost/*"],
    }
  },
  modules: ['@wxt-dev/module-react'],
  webExt: {
    startUrls: ['http://localhost:3038/frontman'],
    chromiumArgs: ['--user-data-dir=./.wxt/chrome-data'],
  },
  dev: {
    server: {
      port: 3131,
    }
  }
});
