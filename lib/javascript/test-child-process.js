const { spawn } = require('child_process');

const command = 'cmd';
const args = ['/C', 'flow', 'emulator', 'start']
const options = {/* your spawn options */ };

const flowProcess = spawn(command, args, options);

flowProcess.stdout.on('data', (data) => {
  console.log(`stdout: ${data}`);
});

flowProcess.stderr.on('data', (data) => {
  console.error(`stderr: ${data}`);
});

flowProcess.on('close', (code) => {
  console.log(`child process exited with code ${code}`);
});
