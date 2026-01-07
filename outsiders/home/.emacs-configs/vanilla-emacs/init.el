;; 1. 패키지 관리자 초기화 (MELPA)
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; 2. 필요한 패키지가 없으면 설치하는 함수 (use-package 없이 간단히 구현)
(defun ensure-package-installed (pkg)
  (unless (package-installed-p pkg)
    (package-refresh-contents)
    (package-install pkg)))

;; 기존에 Nix로 설치했던 geiser와 paredit을 이제 Emacs가 직접 설치하게 합니다.
(ensure-package-installed 'geiser)
(ensure-package-installed 'geiser-guile) ;; Guile 구현체 연결
(ensure-package-installed 'paredit)

;; 3. 사용자 설정 (Nix extraConfig에서 가져옴)
(add-hook 'emacs-lisp-mode-hook 'paredit-mode)
(add-hook 'lisp-mode-hook 'paredit-mode)
(add-hook 'scheme-mode-hook 'paredit-mode)
(add-hook 'clojure-mode-hook 'paredit-mode)

;; Geiser Setup
(setq geiser-default-implementations '((scheme . guile)))
(add-hook 'scheme-mode-hook 'geiser-mode)
(define-key geiser-mode-map (kbd "C-c C-r") 'geiser-restart)

;; 환영 메시지
(message "Vanilla Emacs with Scheme config loaded!")
