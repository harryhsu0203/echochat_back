import Foundation
import UIKit

// MARK: - iOS 使用範例

class LoginViewController: UIViewController {
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        loginButton.layer.cornerRadius = 8
        activityIndicator.isHidden = true
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let username = usernameTextField.text, !username.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "錯誤", message: "請輸入用戶名和密碼")
            return
        }
        
        loginButton.isEnabled = false
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        // 使用 API 客戶端登入
        EchoChatAPIClient.shared.login(username: username, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.loginButton.isEnabled = true
                self?.activityIndicator.stopAnimating()
                self?.activityIndicator.isHidden = true
                
                switch result {
                case .success(let response):
                    print("登入成功: \(response.user.name)")
                    // 儲存用戶資訊到 UserDefaults
                    UserDefaults.standard.set(response.token, forKey: "authToken")
                    UserDefaults.standard.set(response.user.id, forKey: "userId")
                    UserDefaults.standard.set(response.user.name, forKey: "userName")
                    
                    // 導航到主畫面
                    self?.navigateToMainScreen()
                    
                case .failure(let error):
                    self?.showAlert(title: "登入失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func navigateToMainScreen() {
        // 導航到主畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController")
        mainVC.modalPresentationStyle = .fullScreen
        present(mainVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

class RegisterViewController: UIViewController {
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        registerButton.layer.cornerRadius = 8
        activityIndicator.isHidden = true
    }
    
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        guard let username = usernameTextField.text, !username.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "錯誤", message: "請填寫所有欄位")
            return
        }
        
        registerButton.isEnabled = false
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        
        // 使用完整的註冊流程
        EchoChatAPIClient.shared.registerFlow(username: username, email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.registerButton.isEnabled = true
                self?.activityIndicator.stopAnimating()
                self?.activityIndicator.isHidden = true
                
                switch result {
                case .success(_):
                    self?.showAlert(title: "註冊成功", message: "請使用新帳號登入") { _ in
                        self?.dismiss(animated: true)
                    }
                    
                case .failure(let error):
                    self?.showAlert(title: "註冊失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default, handler: completion))
        present(alert, animated: true)
    }
}

class ChatViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    private var messages: [Message] = []
    private var currentConversationId: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadConversations()
    }
    
    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        sendButton.layer.cornerRadius = 8
        
        // 註冊自定義 cell
        tableView.register(UINib(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "MessageCell")
    }
    
    private func loadConversations() {
        EchoChatAPIClient.shared.getConversations { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let conversations = response.data, !conversations.isEmpty {
                        // 載入最新的對話
                        let latestConversation = conversations.first!
                        self?.currentConversationId = latestConversation.id
                        self?.messages = latestConversation.messages
                        self?.tableView.reloadData()
                    }
                    
                case .failure(let error):
                    self?.showAlert(title: "載入失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        guard let message = messageTextField.text, !message.isEmpty else { return }
        
        sendButton.isEnabled = false
        let userMessage = message
        messageTextField.text = ""
        
        // 添加用戶訊息到列表
        let newMessage = Message(role: "user", content: userMessage, timestamp: ISO8601DateFormatter().string(from: Date()))
        messages.append(newMessage)
        tableView.reloadData()
        
        // 發送訊息到 API
        EchoChatAPIClient.shared.sendMessage(userMessage, conversationId: currentConversationId) { [weak self] result in
            DispatchQueue.main.async {
                self?.sendButton.isEnabled = true
                
                switch result {
                case .success(let response):
                    // 添加 AI 回應到列表
                    let aiMessage = Message(role: "assistant", content: response.response, timestamp: response.timestamp)
                    self?.messages.append(aiMessage)
                    self?.currentConversationId = response.conversationId
                    self?.tableView.reloadData()
                    
                    // 滾動到底部
                    self?.scrollToBottom()
                    
                case .failure(let error):
                    self?.showAlert(title: "發送失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func scrollToBottom() {
        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        if lastRow >= 0 {
            let indexPath = IndexPath(row: lastRow, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - TableView 擴展
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        let message = messages[indexPath.row]
        cell.configure(with: message)
        return cell
    }
}

// MARK: - 自定義 Message Cell
class MessageCell: UITableViewCell {
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var bubbleView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        bubbleView.layer.cornerRadius = 12
    }
    
    func configure(with message: Message) {
        messageLabel.text = message.content
        timeLabel.text = formatTime(message.timestamp)
        
        // 根據訊息角色設定樣式
        if message.role == "user" {
            bubbleView.backgroundColor = UIColor.systemBlue
            messageLabel.textColor = UIColor.white
        } else {
            bubbleView.backgroundColor = UIColor.systemGray5
            messageLabel.textColor = UIColor.label
        }
    }
    
    private func formatTime(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        return ""
    }
}

// MARK: - 設定頁面範例
class SettingsViewController: UIViewController {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var logoutButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserProfile()
    }
    
    private func setupUI() {
        logoutButton.layer.cornerRadius = 8
        logoutButton.backgroundColor = UIColor.systemRed
        logoutButton.setTitleColor(UIColor.white, for: .normal)
    }
    
    private func loadUserProfile() {
        EchoChatAPIClient.shared.getProfile { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let user = response.data {
                        self?.nameLabel.text = user.name
                        self?.roleLabel.text = user.role
                    }
                    
                case .failure(let error):
                    self?.showAlert(title: "載入失敗", message: error.localizedDescription)
                }
            }
        }
    }
    
    @IBAction func logoutButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "確認登出", message: "確定要登出嗎？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "登出", style: .destructive) { _ in
            self.performLogout()
        })
        present(alert, animated: true)
    }
    
    private func performLogout() {
        // 清除本地儲存的資料
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userName")
        
        // 清除 API 客戶端的 Token
        EchoChatAPIClient.shared.logout()
        
        // 導航回登入畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
        loginVC.modalPresentationStyle = .fullScreen
        present(loginVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - App Delegate 範例
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 檢查是否已登入
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            // 已登入，直接進入主畫面
            showMainScreen()
        } else {
            // 未登入，顯示登入畫面
            showLoginScreen()
        }
        
        return true
    }
    
    private func showMainScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController")
        window?.rootViewController = mainVC
    }
    
    private func showLoginScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
        window?.rootViewController = loginVC
    }
}

// MARK: - 網路狀態監控
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected: Bool = false
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if self?.isConnected == true {
                    print("網路已連接")
                } else {
                    print("網路已斷開")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - 使用範例總結

/*
 使用步驟：
 
 1. 將 EchoChatAPIClient.swift 加入您的 iOS 專案
 2. 在需要使用 API 的地方引入並使用
 
 基本使用流程：
 
 1. 登入：
    - 用戶輸入用戶名和密碼
    - 調用 EchoChatAPIClient.shared.login()
    - 成功後儲存 Token 並導航到主畫面
 
 2. 聊天：
    - 載入對話歷史
    - 用戶發送訊息
    - 接收 AI 回應
    - 更新 UI
 
 3. 設定：
    - 載入用戶資料
    - 更新個人資料
    - 登出功能
 
 注意事項：
 - 所有網路請求都在背景執行緒進行
 - UI 更新必須在主執行緒進行
 - 記得處理錯誤情況
 - 實作適當的載入狀態指示器
 - 考慮網路狀態監控
 */ 