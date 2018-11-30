import File, { UploadSource, ExternalSource } from './file'
import Header from './header'

export LinkTypes = [
    tag: 'link'
    rel: 'website'
    icon: 'fa-link'
    name: 'Website'
    namePlaceholder: 'ReaPack website'
    urlPlaceholder: 'https://reapack.com'
  ,
    tag: 'screenshot'
    rel: 'screenshot'
    icon: 'fa-picture-o'
    name: 'Screenshot'
    namePlaceholder: 'Docked mode'
    urlPlaceholder: 'https://i.imgur.com/4xPMV9J.gif'
  ,
    tag: 'donation'
    rel: 'donation'
    icon: 'fa-paypal'
    name: 'Donation'
    namePlaceholder: 'Donate via PayPal'
    urlPlaceholder: 'https://paypal.me/cfillion'
]

export default class Package
  constructor: (@type) ->
    @name = ''
    @category = ''
    @author = ''
    @about = ''
    @links = []
    @version = ''
    @changelog = ''
    @files = [new File(null, @, true)]

  linkTag: (type) ->
    for link in @links when link.type.tag == type
      if link.name
        "#{link.name} #{link.url}"
      else
        link.url

  providesTag: ->
    line for file in @files when line = file.providesLine @files[0]

  header: ->
    header = new Header
    header.push 'description', @name if @name
    header.push 'author', @author if @author
    header.push 'version', @version if @version
    header.push 'changelog', @changelog if @changelog
    header.push 'metapackage' unless @files[0].install || @type.metapackage
    header.push 'provides', @providesTag()
    for tag in ['link', 'screenshot', 'donation']
      header.push tag, @linkTag(tag)
    header.push 'about', @about if @about
    header

  findFilesSourcing: (file) ->
    f for f in @files when f.source.file == file

  validateName: (errors) ->
    lowerName = @name.toLowerCase()

    if lowerName.startsWith "#{@author.toLowerCase()}_"
      errors.push 'The display name should not contain an author prefix.'

    for ext in @type.extensions
      ext = ext.toLowerCase()

      if lowerName.endsWith ext
        errors.push 'The display name should not contain the file extension.'
        break

  validateVersion: (errors) ->
    unless @version.match /^\d/
      errors.push 'The version number must begin with a number.'

  validateFiles: (errors) ->
    if @files.find (file) => \
        file.source == UploadSource && !file.effectiveStorageName()
      errors.push "One or more hosted files don't have a storage file name."

    if @files.find (file) => !file.effectiveInstallName()
      errors.push "One or more files don't have an installation file name."

    if @files.find (file) => file.source == ExternalSource && !file.url
      errors.push "One or more external files don't have a download URL."

    dups = []

    for file, index in @files
      continue unless file.source == UploadSource

      storagePath = file.storagePath()

      otherIndex = @files.findIndex (otherFile) =>
        otherFile.source == UploadSource &&
          storagePath == otherFile.storagePath()

      unless otherIndex == index || dups.includes(storagePath)
        errors.push "More than one files are uploaded as '#{storagePath}'."
        dups.push storagePath

      unless file.install || @files.find (otherFile) => otherFile.source.file == file
        errors.push "'#{storagePath}' is unused (not installed and not used as source for another file)."

  validateAll: ->
    errors = []
    validator.call @, errors for validator in [
      @validateName, @validateVersion, @validateFiles
    ]
    errors
