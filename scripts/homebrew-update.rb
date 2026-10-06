require "json"
require "base64"
require "digest"
require "rubygems"

version, archive, existing_file = ARGV
existing = JSON.parse(File.read(existing_file))
cask = Base64.decode64(existing.fetch("content"))
current = cask.match(/^  version "([0-9]+\.[0-9]+\.[0-9]+)"$/)
raise "The cask version was not found." unless current
raise "The release version was invalid." unless version.match?(/\A[0-9]+\.[0-9]+\.[0-9]+\z/)

exit if Gem::Version.new(version) < Gem::Version.new(current[1])

checksum = Digest::SHA256.file(archive).hexdigest
raise "The cask checksum was not found." unless cask.match?(/^  sha256 "[0-9a-f]{64}"$/)

updated = cask.sub(/^  version "[^"]+"$/, "  version \"#{version}\"")
updated = updated.sub(/^  sha256 "[^"]+"$/, "  sha256 \"#{checksum}\"")
exit if updated == cask

puts JSON.generate(
  message: "Update Sonos Keys to #{version}",
  content: Base64.strict_encode64(updated),
  sha: existing.fetch("sha"),
  branch: "main",
  author: { name: "Michael Teeuw", email: "210954+MichMich@users.noreply.github.com" },
  committer: { name: "Michael Teeuw", email: "210954+MichMich@users.noreply.github.com" }
)
