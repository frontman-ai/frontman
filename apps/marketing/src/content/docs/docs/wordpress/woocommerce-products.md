---
title: Edit WooCommerce Product Descriptions with AI
description: Use an AI assistant to inspect WooCommerce products, update one staging description, and check saved content separately from the public product page.
---

Use Frontman to improve one WooCommerce product description without changes to prices, stock, or orders. A useful result explains the product accurately and preserves the rest of its catalog data.
Clear product copy does not guarantee search rankings.

The example prompts are code-backed illustrative procedures, not a record of a live store test.

## Before you start

- [Choose your editing interface](/docs/wordpress/choose-interface/) and complete its setup.
- For an external assistant, read [MCP permissions and revocation](/docs/wordpress/permissions/) before you authorize store access.
- Use a staging store with an existing simple product and a current backup.
- Make sure that WooCommerce is active and the assistant advertises the required `wc_*` tools.
- Use an account with WooCommerce management access and permission for the target product.

Frontman uses the native WooCommerce REST routes with local WordPress authentication.
These tools do not require separate WooCommerce REST API keys.
Other plugins and WooCommerce permissions can restrict a request.

**Caution:** Do not use orders, refunds, payments, or customer records for this exercise.
Those operations can move money, change stock, or send notifications.

## 1. Inspect the store and product

Ask your assistant:

> Work on the staging store at https://your-store.example. Read its site information before any write.
> Find the simple product named “Canvas tote.” Do not change anything.
> Read its full product data. Show its ID, status, permalink, description, and short description.
> Record the original descriptions, prices, and stock values.
> Propose a factual description based only on the current product details. Wait for approval.

For hosted MCP, the assistant starts with `list_sites`, then `wp_get_site_info` for the selected connection.
In the embedded editor, ask it to read the current installation's site information instead of listing hosted connections.
For repeated hostname labels, use [the multiple-sites procedure](/docs/wordpress/multiple-sites/) before any write.
Every hosted site tool requires `site_id`, the connection ID from `list_sites`.

The following call examples use hosted MCP. In the embedded editor, omit `site_id` and use the current site's advertised arguments.
For product discovery, the real tool and arguments are:

```text
wc_get_products({
  "site_id": "<staging-site-id>",
  "perPage": 5,
  "page": 1,
  "filters": {"search": "Canvas tote", "type": "simple"}
})
wc_get_product({"site_id": "<staging-site-id>", "productId": 123})
```

Replace the example connection ID and product ID with returned values.
Search results are candidates, not proof of a unique match.
If several products match, choose the intended product before the assistant continues.

## 2. Approve one description update

Before approval, compare the proposed copy with the product specifications.
Do not invent materials, dimensions, certifications, reviews, or availability.
Keep the product name, URL, prices, stock, images, and publication status outside the task.

> On the selected staging store, update only the description of product 123 to the approved text.
> Leave every other product field unchanged. Do not publish, delete, or create any product.
> Read the product again after the update. Stop after this one product.

After your explicit approval, the assistant uses this shape:

```text
wc_update_product({
  "site_id": "<staging-site-id>",
  "productId": 123,
  "productData": {"description": "<p>The approved factual product description.</p>"},
  "confirm": true
})
```

WooCommerce endpoint tools with `PUT` or `DELETE` require `confirm=true`.
Metadata writes, including `wc_update_product_meta`, also require that field.
The field does not replace your approval of the specific change.

`POST` create tools do not require `confirm=true`.
`wc_create_product` accepts `productData` and can publish immediately or download supplied image URLs.
For a disposable alternative, explicitly request `productData` with `type: "simple"` and `status: "draft"`.
Do not create a product as an automatic fallback after an update failure.

## 3. Check saved data and the public page separately

1. Ask the assistant to call `wc_get_product` again for the same installation and `productId`.
2. Compare the saved description with the approved copy.
3. Compare the recorded status, prices, and stock values with the fresh result.
4. Open the staging product permalink yourself.
5. Inspect the visible description and short description in your browser.

For hosted MCP, retain the same `site_id` for that readback.

A saved description does not prove that the theme displays it in the intended location.
Hosted external assistants do not receive the embedded Frontman preview, screenshots, or DOM tools.
A draft needs an authenticated WordPress preview, not a claim that its public page works.
For supported product SEO titles and descriptions, use [the separate SEO metadata tools](/docs/wordpress/seo-metadata/).

## Recovery and limits

If a write fails or its response disappears, read the product before you retry.
For an uncertain create, search for the new product before another create request.
Identical create requests can produce additional products. No mutation promises duplicate-free retry.

If restoration is necessary, compare the current product with the recorded before-state.
After separate approval, restore only the supported description field with `wc_update_product` and `confirm=true`.
Then read the product again and inspect its page separately.
Frontman does not provide a universal WooCommerce undo or reverse external side effects.
Use [review and recovery](/docs/wordpress/recovery/) to choose the appropriate corrective procedure.
For unavailable tools or connection errors, use [troubleshooting](/docs/wordpress/troubleshooting/).
