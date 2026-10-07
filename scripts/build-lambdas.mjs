import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

async function exists(target) {
  try {
    await access(target);
    return true;
  } catch {
    return false;
  }
}

if (!(await exists(path.join(root, "node_modules/esbuild/package.json")))) {
  execFileSync("npm", ["install"], {
    cwd: root,
    stdio: ["ignore", "ignore", "inherit"],
  });
}

const esbuild = await import("esbuild");

const jobs = [
  {
    name: "request",
    entry: "modules/upload-api/src/request_upload.ts",
    outfile: "modules/upload-api/build/index.js",
  },
  {
    name: "worker",
    entry: "modules/upload-worker/src/process_upload.ts",
    outfile: "modules/upload-worker/build/index.js",
  },
];

const result = {};
for (const job of jobs) {
  await esbuild.build({
    absWorkingDir: root,
    entryPoints: [job.entry],
    outfile: job.outfile,
    bundle: true,
    platform: "node",
    target: "node20",
    format: "cjs",
    logLevel: "silent",
  });
  const built = await readFile(path.join(root, job.outfile));
  result[job.name] = createHash("sha256").update(built).digest("hex");
}

process.stdout.write(JSON.stringify(result));
