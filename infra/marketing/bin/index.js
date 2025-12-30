import * as pulumi from "@pulumi/pulumi";
import * as cloudflare from "@pulumi/cloudflare";
const config = new pulumi.Config();
const accountId = config.require("accountId");
const projectName = config.get("projectName") || "frontman-marketing";
// Create Cloudflare Pages project
// Deployments are handled via Wrangler in CI/CD pipeline
const marketingSite = new cloudflare.PagesProject("marketing", {
    accountId: accountId,
    name: projectName,
    productionBranch: "main", // Required as of v6.11.0
});
// Export outputs for CI/CD and reference
export const pagesProjectName = marketingSite.name;
export const pagesProjectId = marketingSite.id;
export const subdomain = marketingSite.subdomain;
export const url = pulumi.interpolate `https://${marketingSite.subdomain}`;
