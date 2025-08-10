import Foundation
import AVFoundation

class SoundManager : NSObject {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?
    
    // 🆕 音声の重複を防ぐためのフラグ
    private var isPlaying = false
    private var lastPlayTime: Date = Date.distantPast
    private let minimumInterval: TimeInterval = 0.5 // 最小間隔500ms
    
    let availableSounds = ["Radar", "Beacon", "Chimes", "Reflection"]
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ オーディオセッション設定完了")
        } catch {
            print("❌ オーディオセッション設定エラー: \(error)")
        }
    }
    
    // 🔧 改良版: 重複防止機能付き音声再生
    func playSound(named name: String) {
        let now = Date()
        
        // 🆕 重複再生防止チェック
        if isPlaying && now.timeIntervalSince(lastPlayTime) < minimumInterval {
            print("⏸ 音声重複防止: \(name) (前回から\(String(format: "%.1f", now.timeIntervalSince(lastPlayTime)))秒)")
            return
        }
        
        print("🔊 サウンド再生開始: \(name)")
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("❌ サウンドファイルが見つかりません: \(name).mp3")
            listAvailableSounds()
            return
        }
        
        print("✅ サウンドファイル発見: \(url.path)")
        
        do {
            // 🆕 前の再生を確実に停止
            stopSound()
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            
            // 🆕 音量設定（アラーム用に大きめに設定）
            player?.volume = 1.0
            
            print("📋 サウンドファイル情報:")
            print("   - 長さ: \(player?.duration ?? 0) 秒")
            print("   - チャンネル数: \(player?.numberOfChannels ?? 0)")
            print("   - 音量: \(player?.volume ?? 0)")
            
            let success = player?.play() ?? false
            print("🎵 再生結果: \(success ? "成功" : "失敗")")
            
            if success {
                isPlaying = true
                lastPlayTime = now
            } else {
                print("❌ 再生失敗の原因を調査中...")
                checkAudioSessionSettings()
            }
            
        } catch {
            print("❌ サウンド再生エラー: \(error)")
            checkAudioSessionSettings()
        }
    }
    
    // 🆕 フェードイン付き再生
    func playSoundWithFadeIn(named name: String, fadeDuration: TimeInterval = 1.0) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("❌ サウンドファイルが見つかりません: \(name).mp3")
            return
        }
        
        do {
            stopSound()
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = 0.0 // 無音から開始
            
            let success = player?.play() ?? false
            if success {
                isPlaying = true
                lastPlayTime = Date()
                
                // フェードイン効果
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                    guard let self = self, let player = self.player, player.isPlaying else {
                        timer.invalidate()
                        return
                    }
                    
                    let currentVolume = player.volume
                    let newVolume = min(currentVolume + Float(0.1 / fadeDuration), 1.0)
                    player.volume = newVolume
                    
                    if newVolume >= 1.0 {
                        timer.invalidate()
                        print("🎵 フェードイン完了: \(name)")
                    }
                }
                
                print("🎵 フェードイン再生開始: \(name)")
            }
            
        } catch {
            print("❌ フェードイン再生エラー: \(error)")
        }
    }
    
    // 🆕 ループ再生（アラーム用）
    func playLoopingSound(named name: String, loopCount: Int = -1) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("❌ サウンドファイルが見つかりません: \(name).mp3")
            return
        }
        
        do {
            stopSound()
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.volume = 1.0
            player?.numberOfLoops = loopCount // -1で無限ループ
            
            let success = player?.play() ?? false
            if success {
                isPlaying = true
                lastPlayTime = Date()
                print("🔄 ループ再生開始: \(name) (ループ数: \(loopCount == -1 ? "無限" : String(loopCount)))")
            }
            
        } catch {
            print("❌ ループ再生エラー: \(error)")
        }
    }
    
    private func checkAudioSessionSettings() {
        let session = AVAudioSession.sharedInstance()
        print("📱 オーディオセッション情報:")
        print("   - カテゴリ: \(session.category)")
        print("   - モード: \(session.mode)")
        print("   - 他のオーディオ再生中: \(session.isOtherAudioPlaying)")
        print("   - 音量: \(session.outputVolume)")
        print("   - 入力利用可能: \(session.isInputAvailable)")
        print("   - 出力利用可能: \(session.currentRoute.outputs.count > 0)")
        
        // 出力デバイス情報
        for output in session.currentRoute.outputs {
            print("   - 出力デバイス: \(output.portName) (\(output.portType.rawValue))")
        }
    }
    
    // 🔧 修正: publicに変更（AlarmEditViewから呼び出せるように）
    func listAvailableSounds() {
        print("=== 📁 利用可能なサウンドファイル ===")
        for sound in availableSounds {
            if let url = Bundle.main.url(forResource: sound, withExtension: "mp3") {
                print("✅ \(sound).mp3 - \(url.path)")
                
                // ファイルサイズ確認
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[FileAttributeKey.size] as? NSNumber {
                        print("   サイズ: \(fileSize.intValue) bytes")
                    }
                } catch {
                    print("   サイズ確認エラー: \(error)")
                }
                
            } else {
                print("❌ \(sound).mp3 - 見つかりません")
            }
        }
        print("=== 終了 ===")
    }
    
    // 🔧 改良版: 停止処理
    func stopSound() {
        if let player = player, player.isPlaying {
            player.stop()
            print("🛑 サウンド停止: 再生時間 \(String(format: "%.1f", player.currentTime))秒")
        }
        player = nil
        isPlaying = false
    }
    
    // 🆕 フェードアウト付き停止
    func stopSoundWithFadeOut(fadeDuration: TimeInterval = 1.0) {
        guard let player = player, player.isPlaying else {
            stopSound()
            return
        }
        
        let originalVolume = player.volume
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let player = self.player, player.isPlaying else {
                timer.invalidate()
                self?.stopSound()
                return
            }
            
            let currentVolume = player.volume
            let newVolume = max(currentVolume - Float(0.1 / fadeDuration), 0.0)
            player.volume = newVolume
            
            if newVolume <= 0.0 {
                timer.invalidate()
                self.stopSound()
                print("🎵 フェードアウト完了")
            }
        }
        
        print("🎵 フェードアウト開始")
    }
    
    // 🆕 一時停止・再開機能
    func pauseSound() {
        guard let player = player, player.isPlaying else { return }
        player.pause()
        print("⏸ サウンド一時停止")
    }
    
    func resumeSound() {
        guard let player = player, !player.isPlaying else { return }
        player.play()
        isPlaying = true
        lastPlayTime = Date()
        print("▶️ サウンド再開")
    }
    
    // 🆕 音量調整
    func setVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        player?.volume = clampedVolume
        print("🔊 音量調整: \(Int(clampedVolume * 100))%")
    }
    
    // デバッグ用: 全てのサウンドファイルをテスト
    func testAllSounds() {
        print("=== 🧪 全サウンドファイルテスト ===")
        var testIndex = 0
        
        func testNextSound() {
            guard testIndex < availableSounds.count else {
                print("=== ✅ 全テスト完了 ===")
                return
            }
            
            let sound = availableSounds[testIndex]
            print("テスト中: \(sound)")
            playSound(named: sound)
            
            // 3秒後に次のテスト
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.stopSound()
                testIndex += 1
                
                // 1秒の間隔を空けて次のテスト
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    testNextSound()
                }
            }
        }
        
        testNextSound()
    }
    
    // 🆕 現在の再生状態を取得
    var isCurrentlyPlaying: Bool {
        return player?.isPlaying ?? false
    }
    
    var currentPlaybackTime: TimeInterval {
        return player?.currentTime ?? 0
    }
    
    var totalDuration: TimeInterval {
        return player?.duration ?? 0
    }
    
    // 🆕 デバッグ情報の出力
    func printCurrentStatus() {
        print("=== 🎵 SoundManager 状態 ===")
        print("再生中: \(isCurrentlyPlaying)")
        print("内部フラグ: \(isPlaying)")
        print("最終再生時刻: \(formatTime(lastPlayTime))")
        
        if let player = player {
            print("プレイヤー存在: Yes")
            print("現在時刻: \(String(format: "%.1f", player.currentTime))秒")
            print("総時間: \(String(format: "%.1f", player.duration))秒")
            print("音量: \(Int(player.volume * 100))%")
            print("ループ回数: \(player.numberOfLoops)")
        } else {
            print("プレイヤー存在: No")
        }
        print("============================")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - AVAudioPlayerDelegate
extension SoundManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 サウンド再生完了: \(flag ? "成功" : "失敗")")
        self.player = nil
        self.isPlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ サウンドデコードエラー: \(error?.localizedDescription ?? "不明")")
        self.player = nil
        self.isPlaying = false
    }
    
    // 🆕 再生中断時の処理
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        print("📞 オーディオ中断開始（電話着信など）")
        isPlaying = false
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        print("📞 オーディオ中断終了")
        
        // 自動再開するかどうかは設定による
        if flags == AVAudioSession.InterruptionOptions.shouldResume.rawValue {
            resumeSound()
        }
    }
}
