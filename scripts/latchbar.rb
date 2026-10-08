cask "latchbar" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/vaisakh678/latchbar/releases/download/v#{version}/Latchbar-#{version}.zip"
  name "Latchbar"
  desc "Lock apps behind Touch ID, Apple Watch, or your password"
  homepage "https://github.com/vaisakh678/latchbar"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Latchbar.app"

  uninstall quit: "com.cortexlumora.Latchbar"

  zap trash: "~/Library/Preferences/com.cortexlumora.Latchbar.plist"
end
