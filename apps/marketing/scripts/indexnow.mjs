import { fileURLToPath } from "url";
import { dirname, join } from "path";
import { readFileSync, existsSync } from "fs";
import config from "../astro.config.mjs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const distDir = join(__dirname, "..", "dist");
const siteUrl = config.site; // e.g., "https://frontman.sh"
const verificationFileName = "b93ec302-3eda-4805-a374-3d5e0d5d4fa3.txt";
const key = verificationFileName.replace(".txt", "");

// Function to extract URLs from sitemap XML using regex
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

// Function to read sitemap index and get list of sitemap files
function getSitemapFiles() {
  const sitemapIndexPath = join(distDir, "sitemap-index.xml");
  if (!existsSync(sitemapIndexPath)) {
    console.error("Sitemap index not found at:", sitemapIndexPath);
    return [];
  }
  const sitemapIndex = readFileSync(sitemapIndexPath, "utf8");
  return extractUrlsFromSitemap(sitemapIndex);
}

// Function to convert a sitemap URL to a file path in dist
function sitemapUrlToFilePath(sitemapUrl) {
  try {
    const urlObj = new URL(sitemapUrl);
    // Remove the site origin and leading slash
    let path = urlObj.pathname.replace(/^\//, "");
    // If the path is empty, it's the root sitemap (shouldn't happen for chunks)
    if (!path) {
      return null;
    }
    return join(distDir, path);
  } catch (e) {
    console.error("Invalid sitemap URL:", sitemapUrl, e);
    return null;
  }
}

// Function to submit URLs to Bing IndexNow
async function submitToIndexNow(urls) {
  if (urls.length === 0) {
    console.log("No URLs to submit.");
    return;
  }

  const data = JSON.stringify({
    host: new URL(siteUrl).hostname,
    key,
    urlList: urls,
  });

  const options = {
    hostname: "www.bing.com",
    path: "/indexnow",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(data),
    },
  };

  return new Promise((resolve, reject) => {
    // Import https module dynamically to avoid ES module issues
    import("https")
      .then(({ default: https }) => {
        const req = https.request(options, (res) => {
          let chunks = [];
          res.on("data", (chunk) => {
            chunks.push(chunk);
          });
          res.on("end", () => {
            const response = Buffer.concat(chunks).toString();
            console.log(`Bing IndexNow response status: ${res.statusCode}`);
            console.log(`Bing IndexNow response body: ${response}`);
            if (res.statusCode === 200 || res.statusCode === 202) {
              console.log(
                `Successfully submitted ${urls.length} URLs to Bing IndexNow.`,
              );
              resolve();
            } else {
              reject(
                new Error(`Bing IndexNow returned status ${res.statusCode}`),
              );
            }
          });
        });

        req.on("error", (error) => {
          reject(error);
        });

        req.write(data);
        req.end();
      })
      .catch((error) => {
        reject(error);
      });
  });
}

// Main function
async function main() {
  console.log("Starting IndexNow submission...");
  console.log(`Site: ${siteUrl}`);
  console.log(`Key: ${key}`);

  // Check if verification file exists in public
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

  // Get sitemap files from the sitemap index
  const sitemapUrls = getSitemapFiles();
  if (sitemapUrls.length === 0) {
    console.error("No sitemap URLs found in sitemap index.");
    process.exit(1);
  }

  console.log(`Found ${sitemapUrls.length} sitemap(s) in index.`);

  // Collect all URLs from all sitemap files
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

  // Remove duplicates (though sitemap should not have duplicates)
  allUrls = [...new Set(allUrls)];
  console.log(`Total unique URLs to submit: ${allUrls.length}`);

  // Submit to Bing IndexNow
  try {
    await submitToIndexNow(allUrls);
    console.log("IndexNow submission completed successfully.");
  } catch (error) {
    console.error("IndexNow submission failed:", error.message);
    process.exit(1);
  }
}

main().catch(console.error);
