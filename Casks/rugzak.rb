cask "rugzak" do
  version "0.2.0"
  sha256 :no_check

  url "https://github.com/paaloeye/rugzak/releases/download/v#{version}/Rugzak.dmg"
  name "Rugzak"
  desc "Mount and inspect archives seamlessly via macFUSE"
  homepage "https://github.com/paaloeye/rugzak"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"
  depends_on cask: "macfuse"

  app "Rugzak.app"

  zap trash: [
    "~/Library/Application Support/Rugzak",
    "~/Library/Caches/com.paaloeye.Rugzak",
    "~/Library/Preferences/com.paaloeye.Rugzak.plist",
  ]
end
