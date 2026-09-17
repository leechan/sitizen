.PHONY: help build run bundle dmg install icon preview marketing snapshot selftest clean

APP_NAME := Sitizen
DIST     := dist
APP      := $(DIST)/$(APP_NAME).app

help:
	@echo "Sitizen — 你的久坐对手"
	@echo ""
	@echo "  make run       本地调试运行（swift run）"
	@echo "  make build     Debug 编译"
	@echo "  make bundle    打包成 $(APP)（通用二进制 + 签名）"
	@echo "  make dmg       打包成 DMG（需先 make bundle）"
	@echo "  make install   打包并复制到 /Applications 后启动"
	@echo "  make icon      只重新生成 App 图标（用 App 内的吉祥物渲染）"
	@echo "  make preview   把各个界面渲染成 PNG 到 ./previews（设计走查用）"
	@echo "  make marketing 生成产品宣传图到 ./marketing"
	@echo "  make snapshot  抓取真实浮层窗口的快照到 ./snapshots"
	@echo "  make selftest  跑一遍压缩后的完整节奏，验证状态机"
	@echo "  make clean     清理编译产物"
	@echo ""
	@echo "  可选环境变量："
	@echo "    SITIZEN_SIGN_IDENTITY=\"Developer ID Application: ...\"  正式签名"
	@echo "    SITIZEN_ARCHS=\"arm64\"                                  只打单一架构"

build:
	swift build

run:
	swift run

bundle:
	./scripts/bundle.sh

dmg:
	./scripts/make-dmg.sh

install: bundle
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP)" "/Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"
	@echo "已安装到 /Applications/$(APP_NAME).app"

icon: build
	.build/debug/$(APP_NAME) --render-appicon Resources/icon.iconset
	iconutil -c icns Resources/icon.iconset -o Resources/AppIcon.icns

marketing: build
	rm -rf marketing
	.build/debug/$(APP_NAME) --render-marketing marketing
	@echo "已输出到 ./marketing"

preview: build
	rm -rf previews
	.build/debug/$(APP_NAME) --render-previews previews
	@echo "已输出到 ./previews"

snapshot: build
	rm -rf snapshots
	.build/debug/$(APP_NAME) --snapshot snapshots
	@echo "已输出到 ./snapshots"

selftest: build
	.build/debug/$(APP_NAME) --selftest

clean:
	swift package clean
	rm -rf .build $(DIST) previews marketing snapshots
	@echo "已清理"
