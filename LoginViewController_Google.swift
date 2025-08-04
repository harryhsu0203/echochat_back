import UIKit
import GoogleSignIn

class LoginViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var googleSignInButton: GIDSignInButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGoogleSignIn()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 檢查是否已經登入
        if EchoChatAPIClient.shared.isLoggedIn {
            navigateToMainScreen()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 設定標題
        titleLabel.text = "歡迎使用 EchoChat"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        
        // 設定文字欄位
        setupTextFields()
        
        // 設定按鈕
        setupButtons()
        
        // 設定載入指示器
        activityIndicator.isHidden = true
        
        // 設定狀態標籤
        statusLabel.text = "請選擇登入方式"
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemGray
        
        // 設定背景
        view.backgroundColor = UIColor.systemBackground
    }
    
    private func setupTextFields() {
        // 用戶名欄位
        usernameTextField.placeholder = "用戶名"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.autocorrectionType = .no
        usernameTextField.autocapitalizationType = .none
        
        // 密碼欄位
        passwordTextField.placeholder = "密碼"
        passwordTextField.borderStyle = .roundedRect
        passwordTextField.isSecureTextEntry = true
        passwordTextField.autocorrectionType = .no
        passwordTextField.autocapitalizationType = .none
        
        // 添加返回鍵處理
        usernameTextField.returnKeyType = .next
        passwordTextField.returnKeyType = .done
        
        usernameTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    private func setupButtons() {
        // 登入按鈕
        loginButton.setTitle("登入", for: .normal)
        loginButton.backgroundColor = UIColor.systemBlue
        loginButton.setTitleColor(UIColor.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        
        // Google 登入按鈕
        googleSignInButton.style = .wide
        googleSignInButton.colorScheme = .light
        
        // 註冊按鈕
        registerButton.setTitle("註冊新帳號", for: .normal)
        registerButton.setTitleColor(UIColor.systemBlue, for: .normal)
        registerButton.backgroundColor = UIColor.clear
        
        // 忘記密碼按鈕
        forgotPasswordButton.setTitle("忘記密碼？", for: .normal)
        forgotPasswordButton.setTitleColor(UIColor.systemGray, for: .normal)
        forgotPasswordButton.backgroundColor = UIColor.clear
    }
    
    private func setupGoogleSignIn() {
        // 配置 Google Sign-In
        GoogleSignInManager.shared.configure()
    }
    
    // MARK: - Actions
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        performTraditionalLogin()
    }
    
    @IBAction func googleSignInButtonTapped(_ sender: GIDSignInButton) {
        performGoogleSignIn()
    }
    
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        navigateToRegisterScreen()
    }
    
    @IBAction func forgotPasswordButtonTapped(_ sender: UIButton) {
        navigateToForgotPasswordScreen()
    }
    
    // MARK: - Traditional Login
    private func performTraditionalLogin() {
        guard let username = usernameTextField.text, !username.isEmpty else {
            showAlert(title: "錯誤", message: "請輸入用戶名")
            return
        }
        
        guard let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "錯誤", message: "請輸入密碼")
            return
        }
        
        showLoading()
        statusLabel.text = "正在登入..."
        
        EchoChatAPIClient.shared.login(username: username, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoading()
                
                switch result {
                case .success(let response):
                    self?.handleLoginSuccess(response)
                    
                case .failure(let error):
                    self?.handleLoginError(error)
                }
            }
        }
    }
    
    // MARK: - Google Sign-In
    private func performGoogleSignIn() {
        showLoading()
        statusLabel.text = "正在開啟 Google 登入..."
        
        GoogleSignInManager.shared.signIn(presenting: self) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.handleGoogleSignInSuccess(user)
                    
                case .failure(let error):
                    self?.hideLoading()
                    self?.handleGoogleSignInError(error)
                }
            }
        }
    }
    
    private func handleGoogleSignInSuccess(_ user: GIDGoogleUser) {
        guard let idToken = user.idToken else {
            hideLoading()
            showAlert(title: "登入失敗", message: "無法獲取 Google ID Token")
            return
        }
        
        statusLabel.text = "正在驗證..."
        
        // 使用 EchoChat API 進行 Google 登入
        EchoChatAPIClient.shared.loginWithGoogle(idToken: idToken) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoading()
                
                switch result {
                case .success(let response):
                    self?.handleLoginSuccess(response)
                    
                case .failure(let error):
                    self?.handleLoginError(error)
                }
            }
        }
    }
    
    // MARK: - Login Success/Error Handling
    private func handleLoginSuccess(_ response: LoginResponse) {
        // 儲存用戶資訊到 UserDefaults
        saveUserData(response)
        
        statusLabel.text = "登入成功！"
        statusLabel.textColor = .systemGreen
        
        // 顯示成功訊息
        showAlert(title: "登入成功", message: "歡迎回來，\(response.user.name)！") { [weak self] _ in
            self?.navigateToMainScreen()
        }
    }
    
    private func handleLoginError(_ error: EchoChatAPIError) {
        statusLabel.text = "登入失敗"
        statusLabel.textColor = .systemRed
        showAlert(title: "登入失敗", message: error.localizedDescription)
    }
    
    private func handleGoogleSignInError(_ error: Error) {
        statusLabel.text = "Google 登入失敗"
        statusLabel.textColor = .systemRed
        showAlert(title: "Google 登入失敗", message: error.localizedDescription)
    }
    
    // MARK: - Helper Methods
    private func saveUserData(_ response: LoginResponse) {
        let defaults = UserDefaults.standard
        defaults.set(response.token, forKey: "authToken")
        defaults.set(response.user.id, forKey: "userId")
        defaults.set(response.user.username, forKey: "username")
        defaults.set(response.user.name, forKey: "userName")
        defaults.set(response.user.email, forKey: "userEmail")
        defaults.set(response.user.picture, forKey: "userPicture")
        defaults.set(response.user.loginMethod ?? "traditional", forKey: "loginMethod")
        defaults.set(true, forKey: "isLoggedIn")
    }
    
    private func showLoading() {
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
        loginButton.isEnabled = false
        googleSignInButton.isEnabled = false
        registerButton.isEnabled = false
        forgotPasswordButton.isEnabled = false
    }
    
    private func hideLoading() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        loginButton.isEnabled = true
        googleSignInButton.isEnabled = true
        registerButton.isEnabled = true
        forgotPasswordButton.isEnabled = true
    }
    
    private func navigateToMainScreen() {
        // 這裡應該導航到主畫面
        // 根據您的應用程式結構來實現
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainVC = storyboard.instantiateViewController(withIdentifier: "MainViewController") {
            mainVC.modalPresentationStyle = .fullScreen
            present(mainVC, animated: true)
        }
    }
    
    private func navigateToRegisterScreen() {
        // 導航到註冊畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let registerVC = storyboard.instantiateViewController(withIdentifier: "RegisterViewController") {
            navigationController?.pushViewController(registerVC, animated: true)
        }
    }
    
    private func navigateToForgotPasswordScreen() {
        // 導航到忘記密碼畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let forgotPasswordVC = storyboard.instantiateViewController(withIdentifier: "ForgotPasswordViewController") {
            navigationController?.pushViewController(forgotPasswordVC, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default, handler: completion))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            textField.resignFirstResponder()
            performTraditionalLogin()
        }
        return true
    }
} 