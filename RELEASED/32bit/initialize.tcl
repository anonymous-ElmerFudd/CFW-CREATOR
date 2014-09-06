#!/usr/bin/env tclsh8.5
#



set ::PS3MFW_VERSION "1.0.0.0"

set ::CFW_SUPPORT_SCRIPTS {
	"core\\xml.tcl"
	"core\\tar.tcl"
	"core\\ps3mfw_base.tcl"
	"core\\ps3mfw_tasks.tcl"
}

# ----- *** GLOBAL SETTINGS *** ----- #
array set ::options {
	--debug-log true
	--tool-debug false
	--task-verbose false			
	--silent false
	--no-sha1-check true    	
}
# ----- *** END GLOBAL SETTINGS *** ----- #


# ----------------------------------------------------- ##
# initialize all 'setup' variables initially, 
# so we don't blow up upon failure to read in errors

set ::PS3MFW_DIR ""
set ::BUILD_DIR ""
set ::IN_DIR ""
set ::IN_FILE ""
set ::OUT_DIR ""
set ::OUT_FILE ""
set ::program ""
set ::auto_path ""
set ::xmlang ""
set ::env(PS3_KEYS) ""


#set ::PS3MFW_DIR [file dirname [info script]]
set ::PS3MFW_DIR [pwd]
set ::TASKS_DIR [file join ${::PS3MFW_DIR} tasks]
set ::program [file tail [pwd]]
set ::taskfiles [list]
set ::TASKS [list]
set ::RUN_TASKS [list]
set ::taskname ""
set ::arguments [list]
set ::current_opt ""
set ::current_task_opt ""

# --------------------------------------------------- #

# --------------------------------------------------- #
# ------- source in the main 'SUPPORT' scripts ------ #
#
foreach script $::CFW_SUPPORT_SCRIPTS {
	source $script
}
#
# --------------------------------------------------- #


set ::auto_path [linsert ${::auto_path} 0 ${::PS3MFW_DIR}]
append ::env(PATH) ";[file nativename [file join ${::PS3MFW_DIR} tools]]"



## --------------------------------------------------------- ##
## ----- setup the vars from the 'settings.xml' ------------ ##
##															 ##
## --- 'USE the current 'script' directory as the base dir   ##
## ---  for the root directory of all 'settings' options     ##
## ---  (just append any settings to the current script dir  ##

set ::xmlang [::xml::LoadFile [file join $::PS3MFW_DIR Settings.xml]]
if {[file exists [::xml::GetData ${::xmlang} "Settings:PS3_KEYS" 0]]} {
	set ::env(PS3_KEYS) [file join ${::PS3MFW_DIR} [::xml::GetData ${::xmlang} "Settings:PS3_KEYS" 0]]		
} else {
	set ::env(PS3_KEYS) " "
}

set ::BUILD_DIR [file join ${::PS3MFW_DIR} [::xml::GetData ${::xmlang} "Settings:BUILD_DIR" 0]]		
set ::IN_DIR [file join ${::PS3MFW_DIR} [::xml::GetData ${::xmlang} "Settings:IN_DIR" 0]]
set ::IN_FILE [file join ${::IN_DIR} [::xml::GetData ${::xmlang} "Settings:IN_FILE" 0]]	
set ::OUT_DIR [file join ${::PS3MFW_DIR} [::xml::GetData ${::xmlang} "Settings:OUT_DIR" 0]]
set ::OUT_FILE [file join ${::OUT_DIR} [::xml::GetData ${::xmlang} "Settings:OUT_FILE" 0]]		
set ::TASKS [::xml::GetData ${::xmlang} "Settings:tasks" 0]
if {[catch {file mkdir ${::BUILD_DIR}}]} {
	error "error creating build directory:${::BUILD_DIR}"
}
if {[catch {file mkdir ${::IN_DIR}}]} {
	error "error creating in directory:${::IN_DIR}"
}
if {[catch {file mkdir ${::OUT_DIR}}]} {
	error "error creating output directory:${::OUT_DIR}"
}

## 															 ##
## --------------------------------------------------------- ##
## --------------------------------------------------------- ##


# ------------------------------------------- #
# go and read in each task .tcl file
# ------------------------------------------- #
#
# get the total 'taskfiles' list 
# --- !!(sorted by priority) !!! --- 
set ::taskfiles [get_sorted_task_files]

# now 'source' in each task file to process
# the tcl file
foreach taskfile ${::taskfiles} {
	source ${::taskfile}
}
#
# ------------------------------------------- #


# ORIGINAL 'PUP' file locations
set ::ORIGINAL_PUP_DIR [file join ${::BUILD_DIR} PS3MFW-OFW]
set ::CUSTOM_PUP_DIR [file join ${::BUILD_DIR} PS3MFW-MFW]
set ::LOG_FILE [file join ${::BUILD_DIR} "cfw-creator.log"]


set ::PUP "pup"
set ::LV0TOOL "lv0tool.exe"
set ::PKGTOOL "pkgtool.exe"
set ::PATCHTOOL "patchtool.exe"
set ::SCETOOL "scetool"
set ::fciv "fciv"
set ::RCOMAGE "rcomage"
set ::OFW_2NDGEN_BASE "3.56"
set ::NEWMFW_VER "000"
set ::SHCHK "true"
set ::SHADD "false"
set ::SELF ""
set ::SUF ""
set ::CFW 0
set ::OFW_MAJOR_VER 0
set ::OFW_MINOR_VER 0
set ::FLAG_PATCH_USE_PATCHTOOL	1
set ::FLAG_PATCH_FILE_NOPATCH 0
set ::FLAG_PATCH_FILE_MULTI 0
set ::FLAG_NO_LV1LDR_CRYPT 0
set ::FLAG_COREOS_UNPACKED 0
set ::FLAG_4xx_LV0_UNPACKED 0



# ORIGINAL (OFW) base files
set ::ORIGINAL_VERSION_TXT [file join ${::ORIGINAL_PUP_DIR} version.txt]
set ::ORIGINAL_LICENSE_XML [file join ${::ORIGINAL_PUP_DIR} license.xml]
set ::ORIGINAL_PROMO_FLAGS_TXT [file join ${::ORIGINAL_PUP_DIR} promo_flags.txt]
set ::ORIGINAL_UPDATE_FLAGS_TXT [file join ${::ORIGINAL_PUP_DIR} update_flags.txt]
set ::ORIGINAL_PS3SWU_SELF [file join ${::ORIGINAL_PUP_DIR} ps3swu.self]
set ::ORIGINAL_PS3SWU2_SELF [file join ${::ORIGINAL_PUP_DIR} ps3swu2.self]
set ::ORIGINAL_SPKG_TAR [file join ${::ORIGINAL_PUP_DIR} spkg_hdr.tar]
set ::ORIGINAL_UPDATE_TAR [file join ${::ORIGINAL_PUP_DIR} update_files.tar]
set ::ORIGINAL_SPKG_DIR [file join ${::ORIGINAL_PUP_DIR} spkg_hdr]
set ::ORIGINAL_UPDATE_DIR [file join ${::ORIGINAL_PUP_DIR} update_files]
set ::ORIGINAL_PKG_DIR [file join ${::ORIGINAL_UPDATE_DIR} CORE_OS_PACKAGE.pkg]
set ::ORIGINAL_UNPKG_DIR [file join ${::ORIGINAL_UPDATE_DIR} CORE_OS_PACKAGE.unpkg]
set ::ORIGINAL_COSUNPKG_DIR [file join ${::ORIGINAL_UPDATE_DIR} CORE_OS_PACKAGE]

# update (MFW) base files
set ::CUSTOM_VERSION_TXT [file join ${::CUSTOM_PUP_DIR} version.txt]
set ::CUSTOM_LICENSE_XML [file join ${::CUSTOM_PUP_DIR} license.xml]
set ::CUSTOM_PROMO_FLAGS_TXT [file join ${::CUSTOM_PUP_DIR} promo_flags.txt]
set ::CUSTOM_UPDATE_FLAGS_TXT [file join ${::CUSTOM_PUP_DIR} update_flags.txt]
set ::CUSTOM_PS3SWU_SELF [file join ${::CUSTOM_PUP_DIR} ps3swu.self]
set ::CUSTOM_PS3SWU2_SELF [file join ${::CUSTOM_PUP_DIR} ps3swu2.self]
set ::CUSTOM_SPKG_TAR [file join ${::CUSTOM_PUP_DIR} spkg_hdr.tar]
set ::CUSTOM_UPDATE_TAR [file join ${::CUSTOM_PUP_DIR} update_files.tar]
set ::CUSTOM_SPKG_DIR [file join ${::CUSTOM_PUP_DIR} spkg_hdr]
set ::CUSTOM_UPDATE_DIR [file join ${::CUSTOM_PUP_DIR} update_files]
set ::CUSTOM_PKG_DIR [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.pkg]
set ::CUSTOM_UNPKG_DIR [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.unpkg]
set ::CUSTOM_COSUNPKG_DIR [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE]

# update_files.tar pkg files (OFW & MFW)
set ::CUSTOM_DEVFLASH_DIR [file join ${::CUSTOM_UPDATE_DIR} dev_flash]
set ::ORIGINAL_DEVFLASH_DIR [file join ${::ORIGINAL_UPDATE_DIR} dev_flash]
set ::CUSTOM_UPLXML_DIR [file join ${::CUSTOM_UPDATE_DIR} UPL.xml]

# custom dirs
set ::CUSTOM_TEMPLAT_DIR [file join ${::PS3MFW_DIR} templat]
set ::CUSTOM_IMG_DIR [file join ${::CUSTOM_TEMPLAT_DIR} imgs]
set ::CUSTOM_TEMPLAT_RAF [file join ${::CUSTOM_TEMPLAT_DIR} coldboot_raf]
set ::CUSTOM_TEMPLAT_AC3 [file join ${::CUSTOM_TEMPLAT_DIR} coldboot_ac3]
set ::QRCBASE [file join ${::CUSTOM_TEMPLAT_DIR} lines.qrc]
set ::CUSTOM_DEV2_DIR [file join ${::CUSTOM_DEVFLASH_DIR} dev_flash]
set ::CUSTOM_DEV_MODULE [file join ${::CUSTOM_DEV2_DIR} vsh module]
set ::CUSTOM_MFW_DIR [file join ${::CUSTOM_DEV2_DIR} mfw]
set ::C_PS3_GAME [file join ${::CUSTOM_TEMPLAT_DIR} PS3_GAMES]
set ::C_PS3_GAME_AC1D [file join ${::C_PS3_GAME} ac1d]
set ::C_PS3_GAME_ROG [file join ${::C_PS3_GAME} rog]
set ::CUSTOM_PS3_GAME [file join ${::C_PS3_GAME_ROG} PS3_GAME]
set ::CUSTOM_PS3_GAME2 [file join ${::C_PS3_GAME_AC1D} PS3_GAME]
set ::DCINAVIA [file join ${::CUSTOM_TEMPLAT_DIR} videoplayer_plugin.sprx]
set ::RCINAVIA [file join ${::CUSTOM_DEV_MODULE} videoplayer_plugin.sprx]

# modification files
set ::CUSTOM_UPL_XML [file join ${::CUSTOM_UPLXML_DIR} UPL.xml]

# version info
set ::PUP_BUILD ""

# any final custom 'global' enables/disables
if {$::options(--no-sha1-check)} {
	set ::SHCHK "false"
}





