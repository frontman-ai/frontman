import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { readFileSync, existsSync } from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const distDir = join(__dirname, "..", "dist");
const siteUrl = "https://frontman.sh";
const verificationFileName = "b93ec302-3eda-4805-a374-3d5e0d5d4fa3.txt";
const key = verificationFileName.replace(".txt", "");

function extractUrlsFromSitemap(xml) {
  const urlRegex = /<loc>(.*?)<\/loc>/g;
  const urls = [];
  let match;
  while (true) {
    match = urlRegex.exec(xml);
    if (match === null) {
      break;
    }
    urls.push(match[1]);
  }
  return urls;
}

function getSitemapFiles() {
  const sitemapIndexPath = join(distDir, "sitemap-index.xml");
  if (!existsSync(sitemapIndexPath)) {
    console.error("Sitemap index not found at:", sitemapIndexPath);
    return [];
  }
  const sitemapIndex = readFileSync(sitemapIndexPath, "utf8");
  return extractUrlsFromSitemap(sitemapIndex);
}

function sitemapUrlToFilePath(sitemapUrl) {
  try {
    const urlObj = new URL(sitemapUrl);
    let path = urlObj.pathname.replace(/^\//, "");
    if (!path) {
      return null;
    }
    return join(distDir, path);
  } catch (e) {
    console.error("Invalid sitemap URL:", sitemapUrl, e);
    return null;
  }
}

async function submitToIndexNow(urls) {
  if (urls.length === 0) {
    console.log("No URLs to submit.");
    return;
  }

  const body = JSON.stringify({
    host: new URL(siteUrl).hostname,
    key,
    urlList: urls,
  });

  const response = await fetch("https://www.bing.com/indexnow", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });

  const responseText = await response.text();
  console.log(`Bing IndexNow response status: ${response.status}`);
  console.log(`Bing IndexNow response body: ${responseText}`);

  if (response.status !== 200 && response.status !== 202) {
    throw new Error(`Bing IndexNow returned status ${response.status}`);
  }

  console.log(
    `Successfully submitted ${urls.length} URLs to Bing IndexNow.`,
  );
}

async function main() {
  console.log("Starting IndexNow submission...");
  console.log(`Site: ${siteUrl}`);
  console.log(`Key: ${key}`);

  const verificationFilePath = join(
    __dirname,
    "..",
    "public",
    verificationFileName,
  );
  if (!existsSync(verificationFilePath)) {
    console.error(`Verification file not found at: ${verificationFilePath}`);
    console.error(
      "Please ensure the Bing verification file is present in the public directory.",
    );
    process.exit(1);
  }

  const sitemapUrls = getSitemapFiles();
  if (sitemapUrls.length === 0) {
    console.error("No sitemap URLs found in sitemap index.");
    process.exit(1);
  }

  console.log(`Found ${sitemapUrls.length} sitemap(s) in index.`);

  let allUrls = [];
  for (const sitemapUrl of sitemapUrls) {
    const filePath = sitemapUrlToFilePath(sitemapUrl);
    if (!filePath || !existsSync(filePath)) {
      console.warn(`Sitemap file not found or invalid: ${sitemapUrl}`);
      continue;
    }

    const sitemapContent = readFileSync(filePath, "utf8");
    const urls = extractUrlsFromSitemap(sitemapContent);
    console.log(`Extracted ${urls.length} URLs from ${sitemapUrl}`);
    allUrls = allUrls.concat(urls);
  }

  allUrls = [...new Set(allUrls)];
  console.log(`Total unique URLs to submit: ${allUrls.length}`);

  try {
    await submitToIndexNow(allUrls);
    console.log("IndexNow submission completed successfully.");
  } catch (error) {
    console.error("IndexNow submission failed:", error.message);
    process.exit(1);
  }
}

main();
