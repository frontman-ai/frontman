import { defineConfig } from 'wxt';

// See https://wxt.dev/api/config.html
export default defineConfig({
  manifest: {
    //kfdpjbmabcelpgoipaccjijhehdmeghp
    key: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5ucRZpSZ9epesfagtLnNDsiLwh5WwFwJeMjgqxwsVnQ6jnrDFoRxMpBaPNUraRpmZtbYhjm5nk7odvhp+jcoyiln3iBnf7ri8YQ/XFRE6CqLC8+xXbURuZL+MkVeyfJ8mrsDhaAp64Vmu2C9EQROXA+7Rg5xkCxL1UxSWPweFyeh7yUwNlaCZvMYTLXOPnLwI+xipcvOYIjd56PEDT8CFuTsfngB5Y87+pVKAdaRlkqgCrWI8ZHbk9Q0Vxt3FTRprEJ7U+W/hngHIuUedlfpZlN+6Qo0nSY6LrEZ86Ly94ZiEOpz0tm2Z35fCFbGknV4lmEXFvX795CXZ+j2Laqu5QIDAQAB",
    externally_connectable: {
      ids: ['*'],
      matches: ['https://www.figma.com/design/*', 'https://figma.com/design/*', "http://localhost/*"],
    }
  },
  modules: ['@wxt-dev/module-react'],
  webExt: {
    // startUrls: ['http://localhost:3000/__frontman', 'https://www.figma.com/design/vUBfiAH3Z6HVk6QWN2laXF/Figma-Basics?node-id=25-2&t=lyxMqTPOAYyKzJ8Q-0'],
    startUrls: ['http://localhost:3038/__frontman', 'https://www.figma.com/design/CsWO3HE6ZoHY1iAXOzGZcd/Glitter-AI-Pricing-Page?node-id=0-1&p=f&t=p7mO1OfAQ9Yymia6-0'],
    chromiumArgs: ['--user-data-dir=./.wxt/chrome-data'],
  },
  dev: {
    server: {
      port: 3131,
    }
  }
});
