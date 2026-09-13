// Run with Node.js from any directory; OpenScreen and FFmpeg must be installed.
import { readFileSync, writeFileSync, copyFileSync, mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const directory = dirname(fileURLToPath(import.meta.url));
const project = JSON.parse(readFileSync(join(directory, 'voice-typing.openscreen'), 'utf8'));
project.media.screenVideoPath = resolve(directory, project.media.screenVideoPath);
const output = process.argv[2] ? resolve(process.argv[2]) : join(directory, 'voice-typing.gif');
if (!output.toLowerCase().endsWith('.gif')) throw new Error('Output must end in .gif');
const videoOutput = output.slice(0, -4) + '.mp4';
const temporary = mkdtempSync(join(tmpdir(), 'tiro-demo-render-'));
const projectPath = join(temporary, 'voice-typing.openscreen');
const videoPath = join(temporary, 'voice-typing.mp4');
const openscreen = process.env.OPENSCREEN_BIN || '/Applications/Openscreen.app/Contents/MacOS/Openscreen';

function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} exited with ${result.status}`);
}

try {
  // This OpenScreen version requires an absolute media path. Keep it out of Git.
  writeFileSync(projectPath, JSON.stringify(project, null, 2));
  run(openscreen, ['export', projectPath, '--out', videoPath, '--format', 'mp4', '--quality', 'source', '--json']);
  // Optimize the palette and preserve 30-fps timing with GIF's centisecond delays.
  run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', videoPath,
    '-filter_complex', 'fps=30,scale=1280:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
    '-loop', '0', output]);
  copyFileSync(videoPath, videoOutput);
  console.log(`Rendered ${output} and ${videoOutput}`);
} finally {
  for (const file of [projectPath, videoPath]) {
    try { unlinkSync(file); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  rmdirSync(temporary);
}
