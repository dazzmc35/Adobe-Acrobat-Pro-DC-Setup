﻿#region Privacy & Telemetry
# Remove Adobe Acrobat Pro DC update tasks from startup
# Удалить из автозагрузки задачи Adobe Acrobat Pro DC по обновлению
Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -Name AdobeAAMUpdater-1.0, AdobeGCInvoker-1.0 -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run -Name "Acrobat Assistant 8.0" -Force -ErrorAction SilentlyContinue
# Remove Adobe Acrobat Pro DC from context menu
# Удалить пункты Adobe Acrobat Pro DC из контекстного меню
$Arguments = @"
	"/u" "/s" "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat Elements\ContextMenuShim64.dll"
"@
Start-Process -FilePath regsvr32.exe -ArgumentList $Arguments
# Turn off services
# Отключить службы
$services = @(
	# Adobe Acrobat Update Service
	"AdobeARMservice"
	# Adobe Genuine Monitor Service
	"AGMService"
	# Adobe Genuine Software Integrity Service
	"AGSService"
)
Get-Service -ServiceName $services | Stop-Service
Get-Service -ServiceName $services | Set-Service -StartupType Disabled
# Disable update tasks
# Отключить задачи по обновлению
Get-ScheduledTask -TaskName "Adobe Acrobat Update Task", AdobeGCInvoker-1.0* | Disable-ScheduledTask
#endregion Privacy & Telemetry

#region Addons
# Remove Firefox addons
# Удалить расширение в Firefox
Remove-ItemProperty HKLM:\SOFTWARE\Mozilla\Firefox\Extensions -Name *acrobat.adobe.com -Force -ErrorAction SilentlyContinue
Remove-Item -Path "${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Browser" -Recurse -Force -ErrorAction SilentlyContinue
# Remove COM Add-Ins for Office
# Удалить надстройки COM Adobe Acrobat Pro DC для Office
Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Office\*\Addins\PDF* -Force -ErrorAction SilentlyContinue
Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Office\*\Addins\Adobe* -Force -ErrorAction SilentlyContinue
Remove-Item -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\*\Addins\PDF* -Force -ErrorAction SilentlyContinue
Remove-Item -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\*\Addins\Adobe* -Force -ErrorAction SilentlyContinue
#endregion Addons

#region Task
# Create a task in the Task Scheduler to configure Adobe Acrobat Pro DC
# The task runs every 31 days
# Создать задачу в Планировщике задач по настройке Adobe Acrobat Pro DC
# Задача выполняется каждые 31 дней
$action = New-ScheduledTaskAction -Execute powershell.exe -Argument @"
	Get-Service -Name AdobeARMservice | Set-Service -StartupType Disabled
	Get-Service -Name AdobeARMservice | Stop-Service
	Stop-Process -Name acrotray -Force
	Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' | Disable-ScheduledTask
	Get-ScheduledTask -TaskName AdobeGCInvoker-1.0* | Disable-ScheduledTask
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -Name AdobeAAMUpdater-1.0, AdobeGCInvoker-1.0 -Force
	Remove-ItemProperty -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run -Name 'Acrobat Assistant 8.0' -Force
	regsvr32.exe /u /s '${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat Elements\ContextMenuShim64.dll'
	Remove-ItemProperty HKLM:\SOFTWARE\Mozilla\Firefox\Extensions -Name *acrobat.adobe.com -Force
	Remove-Item -Path '${env:ProgramFiles(x86)}\Adobe\Acrobat DC\Acrobat\Browser' -Recurse -Force
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Office\*\Addins\PDF* -Force
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Office\*\Addins\Adobe* -Force
	Remove-Item -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\*\Addins\PDF* -Force
	Remove-Item -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\*\Addins\Adobe* -Force
"@
$trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 31 -At 9am
$settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest
$params = @{
	"TaskName"	= "Acrobat Pro DC"
	"Action"	= $action
	"Trigger"	= $trigger
	"Settings"	= $settings
	"Principal"	= $principal
}
Register-ScheduledTask @params -Force
#endregion Task

#region UI
# Turn off both updates to the product's web-plugin components as well as all services
# Отключить обновление компонентов веб-плагинов, всех сервисов Adobe и вход в учетную запись
IF (-not (Test-Path -Path "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockdown\cServices"))
{
	New-Item -Path "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockdown\cServices" -Force
}
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockdown\cServices" -Name bUpdater -Value 0 -Force
# Turn off all Document Cloud service access
# Отключить все сервисы Adobe Document Cloud
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockdown\cServices" -Name bToggleAdobeDocumentServices -PropertyType DWord -Value 1 -Force
# Turn off preference synchronization across devices
# Отключить синхронизацию между устройствами
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockdown\cServices" -Name bTogglePrefsSync -PropertyType DWord -Value 1 -Force
# Do not show messages from Adobe when the product launches
# Не показывать сообщения от Adobe при запуске
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\IPM"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\IPM" -Force
}
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\HomeWelcomeFirstMile" -Name bShowMsgAtLaunch -PropertyType DWord -Value 0 -Force
# Callapse all tips on the main page
# Свернуть подсказки на главной странице
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\HomeWelcomeFirstMile"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\HomeWelcomeFirstMile" -Force
}
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\HomeWelcomeFirstMile" -Name bFirstMileMinimized -PropertyType DWord -Value 1 -Force
# Always use page Layout Style: "Single Pages Contininuous"
# Всегда использовать стиль макета страницы: "Постранично непрерывно"
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\Access"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\Access" -Force
}
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\Access" -Name bOverridePageLayout -PropertyType DWord -Value 1 -Force
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\Access" -Name iPageLayout -PropertyType DWord -Value 2 -Force
# Turn on dark theme
# Включить темную тему
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name aActiveUITheme -PropertyType String -Value DarkTheme -Force
# Hide "Share" button lable from Toolbar
# Скрыть значок кнопки "Общий доступ" с панели инструментов
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name bHideShareButtonLabel -PropertyType DWord -Value 1 -Force
# Collapse Task Pane
# Свернуть область задач
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral" -Name aDefaultRHPViewModeL -PropertyType String -Value AppSwitcherOnly -Force
# Left "Edit PDF" and "Organize Pages" only tools in the Task Pane
# Оставить в области задач только кнопки "Редактировать PDF" и "Систематизировать страницы"
Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name * -Force
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name a0 -PropertyType String -Value EditPDFApp -Force
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AcroApp\cFavorites" -Name a1 -PropertyType String -Value PagesApp -Force
# Restore last view settings when reopening documents
# Восстанавливать при открытии документов прежние параметры просмотра
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews" -Force
}
New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\RememberedViews" -Name iRememberView -PropertyType DWord -Value 2 -Force
#endregion UI

#region Quick Tools
# Clear favorite Quick Tools (сommented out)
# Очистить Избранное на панели инструментов (закомментировано)
# Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name * -Force -ErrorAction SilentlyContinue
# Clear Quick Tools (сommented out)
# Очистить панель инструментов (закомментировано)
# Remove-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name * -Force -ErrorAction SilentlyContinue
# Show Quick Tools in Toolbar
# Отобразить инструменты быстрого доступа на панели инструментов
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Force
}
$match = '^' + 'a' + '\d+'
# "Save file"
# "Сохранить файл"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
IF ($names)
{
	IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Save")
	{
		New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Save -Force
	}
}
Else
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a0" -PropertyType String -Value Save -Force
}
# "Print file"
# "Печатать файл"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Print")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Print -Force
}
# "Undo last change"
# "Отменить последнее изменение"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Undo")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Undo -Force
}
# "Redo last change"
# "Повторить последнее изменение"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "Redo")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value Redo -Force
}
# "Page number"
# "Номер страницы"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop").Property
IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name $names) -notcontains "GoToPage")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cCommonToolsDesktop" -Name "a$int" -PropertyType String -Value GoToPage -Force
}
# "Rotate counterclockwise. Change is saved"
# "Повернуть текущий вид против часовой стрелке. Изменение сохраняется"
IF (-not (Test-Path -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop"))
{
	New-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Force
}
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property
IF ($names)
{
	IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name $names) -notcontains "RotatePagesCCW")
	{
		New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a$int" -PropertyType String -Value RotatePagesCCW -Force
	}
}
Else
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a0" -PropertyType String -Value RotatePagesCCW -Force
}
# "Rotate clockwise. Change is saved"
# "Повернуть текущий вид по часовой стрелке. Изменение сохраняется"
[int]$int = ((Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property | Where-Object -FilterScript {$_ -match $match}).Count
$names = (Get-Item -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop").Property
IF ((Get-ItemPropertyValue -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name $names) -notcontains "RotatePagesCW")
{
	New-ItemProperty -Path "HKCU:\Software\Adobe\Adobe Acrobat\DC\AVGeneral\cFavoritesCommandsDesktop" -Name "a$int" -PropertyType String -Value RotatePagesCW -Force
}
#endregion Quick Tools