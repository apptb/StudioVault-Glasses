import { Template, defaultBuildLogger } from 'e2b'

const template = Template()
  .fromImage('ubuntu:24.04')
  .setUser('root')
  .setWorkdir('/')
  .runCmd('apt-get update && apt-get install -y curl ca-certificates git && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs && apt-get clean && rm -rf /var/lib/apt/lists/*')
  .runCmd('mkdir -p /home/user/agent /home/user/workspace')
  .setWorkdir('/home/user/agent')
  .copy('e2b/agent/package.json', '/home/user/agent/')
  .runCmd('npm install')
  .copy('e2b/agent/run.mjs', '/home/user/agent/')
  .copy('e2b/agent/server.mjs', '/home/user/agent/')
  .setUser('user')

async function main() {
  const result = await Template.build(template, 'matcha-agent', {
    onBuildLogs: defaultBuildLogger(),
  })
  console.log('\nTemplate built successfully!')
  console.log('Template ID:', result.templateId)
  console.log('Build ID:', result.buildId)
}

main().catch(console.error)
