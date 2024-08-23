import fs from 'fs'
import yaml from 'js-yaml'
import path from 'path'

export const readYamlFile = (ymlPath) => {
  if (!fs.existsSync(ymlPath)) {
    return null
  }
  try {
    const fileContent = fs.readFileSync(ymlPath, 'utf8')
    return yaml.load(fileContent)
  } catch (error) {
    return null
  }
}

export const yamlDump = (data) => {
  return yaml.dump(data, { sortKeys: false })
}

export const writeFile = (dir, filename, content) => {
  try {
    const filepath = path.join(dir, filename)
    fs.mkdirSync(path.dirname(filepath), { recursive: true })
    fs.writeFileSync(filepath, content)
  } catch (error) {
    throw new Error(`Error writing file: ${filepath}\n${error}`)
  }
}

export const copyFile = (from, dest) => {
  try {
    fs.mkdirSync(path.dirname(dest), { recursive: true })
    fs.copyFileSync(from, dest)
  } catch (error) {
    throw new Error(`Error copying ${error}`)
  }
}

export const removeDir = (directoryPath) => {
  try {
    fs.rmSync(directoryPath, { recursive: true, force: true })
  } catch (err) {
    throw new Error(`Error remove dir ${err}`)
  }
}
