import { Template } from 'e2b'

export const template = Template()
  .fromImage('ubuntu:24.04')
  .setUser('root')
  .setWorkdir('/')
  .runCmd('apt-get update && apt-get install -y curl ca-certificates git && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs && apt-get clean && rm -rf /var/lib/apt/lists/*')
  .runCmd('mkdir -p /home/user/agent /home/user/workspace')
  .setWorkdir('/home/user/agent')
  .copy('agent/package.json', '/home/user/agent/')
  .runCmd('npm install')
  .copy('agent/run.mjs', '/home/user/agent/')
  .setUser('user')
