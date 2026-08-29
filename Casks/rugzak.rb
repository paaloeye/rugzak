cask "rugzak" do
  version "0.2.1"
  sha256 "4f1e4b8513028e75dcd6279159220668b19bbb4bec44b3fdd01e0c58448a3dce"

  url "https://github.com/paaloeye/rugzak/releases/download/v#{version}/Rugzak-0.2-6643f1e.dmg"
  name "Rugzak"
  desc "Mount and inspect archives seamlessly via macFUSE"
  homepage "https://github.com/paaloeye/rugzak"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma
  depends_on cask: "macfuse"

  app "Rugzak.app"

  zap trash: [
    "~/Library/Application Support/Rugzak",
    "~/Library/Caches/com.paaloeye.Rugzak",
    "~/Library/Preferences/com.paaloeye.Rugzak.plist",
  ]
end
