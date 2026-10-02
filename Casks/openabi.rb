cask "openabi" do
  version "1.1.0"
  sha256 "934c361fdcbcfb3a794f0f051c2b75b56806fd3e024dc6f8d2d10552d910afb3"

  url "https://github.com/firatmelih/OpenAbi/releases/download/v#{version}/OpenAbi.dmg"
  name "OpenAbi"
  desc "Open folders and files in your apps from Finder's right-click menu"
  homepage "https://firatmelih.github.io/OpenAbi/"

  livecheck do
    url "https://firatmelih.github.io/OpenAbi/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on macos: :sonoma

  app "OpenAbi.app"

  zap trash: [
    "~/Library/Application Scripts/com.melihfirat.OpenAbi.FinderExtension",
    "~/Library/Caches/com.melihfirat.OpenAbi",
    "~/Library/Containers/com.melihfirat.OpenAbi.FinderExtension",
    "~/Library/Group Containers/XQH36L7379.com.melihfirat.OpenAbi",
    "~/Library/HTTPStorages/com.melihfirat.OpenAbi",
    "~/Library/Preferences/com.melihfirat.OpenAbi.plist",
  ]
end
