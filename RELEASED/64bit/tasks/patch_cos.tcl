#!/usr/bin/tclsh
#
# ps3mfw -- PS3 MFW creator
#
# Copyright (C) Anonymous Developers (Code Monkeys)
#
# This software is distributed under the terms of the GNU General Public
# License ("GPL") version 3, as published by the Free Software Foundation.
#

# Priority: 0001
# Description: REQ'D - **CORE-OS PATCHES**

# Option --patch-lv0-nodescramble-lv1ldr: [3.xx/4.xx]  LV0: --> Patch LV0 to disable LV0 descrambling of LV1LDR (3.xx/4.xx)
# Option --patch-lv0-ldrs-ecdsa-checks: [3.xx/4.xx]  LV0: --> Patch LV0 LDRS to disable ECDSA checks in ALL LV0-loaders (3.xx/4.xx)
# Option --patch-lv1-peek-poke: [3.xx/4.xx]  LV1: --> Patch LV1 for peek/poke support (unused lv1 calls 182 and 183) (3.xx/4.xx)
# Option --patch-lv1-remove-lv2-protection: [3.xx/4.xx]  LV1: --> Patch LV1 to remove LV2 protection (3.xx/4.xx)
# Option --patch-lv1-coreos-hash-check: [3.xx/4.xx]  LV1: --> Patch LV1 to disable CoreOS Hash check. Product mode always on (downgrader)
# Option --patch-lv1-sysmgr-disable-integrity-check: [3.xx/4.xx]  LV1: --> Patch LV1 to disable integrity check in System Manager (OtherOS++/downgrader)
# Option --patch-lv2-peek-poke-4x: [3.xx/4.xx]  LV2: --> Patch LV2 to add Peek&Poke system calls (3.xx/4.xx)
# Option --patch-lv2-lv1-peek-poke-4x: [3.xx/4.xx]  LV2: --> Patch LV2 to add LV1 Peek&Poke system calls (LV1 peek/poke patch necessary) (3.xx/4.xx)
# Option --patch-lv2-npdrm-ecdsa-check: [3.xx/4.xx]  LV2: --> Patch LV2 to disable NPDRM ECDSA check  (Jailbait) (3.xx/4.xx)
# Option --patch-lv2-SC36-4x: [3.xx/4.xx]  LV2: --> Patch LV2 to implement SysCall36 (3.xx/4.xx)
# Option --patch-misc-rogero-patches: [3.xx/4.xx]  LV2: --> Patch LV2 with misc ROGERO patches
# Option --patch-lv2-payload-hermes-4x: [3.xx/4.xx]  LV2: --> Patch LV2 to implement hermes payload SC8 /app_home/ redirection & embedded app mount (3.xx/4.xx)
# Option --patch-spkg-ecdsa-check: [3.xx/4.xx]  ALT: --> Patch SPU PKG Verifier to disable ECDSA check for spkg files (spu_pkg_rvk_verifier.self) (3.xx/4.xx)
# Option --patch-sppverifier-ecdsa-check: [3.xx/4.xx]  ALT: --> Patch SPP Verifier to disable ECDSA check (spp_verifier.self) (3.xx/4.xx)
# Option --patch-sputoken-ecdsa-check: [3.xx/4.xx]  ALT: --> Patch SPU Token Processor to disable ECDSA check (spu_token_processor.self) (3.xx/4.xx)
# Option --patch-RSOD-bypass: [3.xx/4.xx]  ALT: --> Patch BASIC_PLUGINS to bypass RSOD errors (3.xx/4.xx)

# Type --patch-lv0-nodescramble-lv1ldr: boolean
# Type --patch-lv0-ldrs-ecdsa-checks: boolean
# Type --patch-lv1-peek-poke: boolean
# Type --patch-lv1-remove-lv2-protection: boolean
# Type --patch-lv1-coreos-hash-check: boolean
# Type --patch-lv1-sysmgr-disable-integrity-check: boolean
# Type --patch-lv2-peek-poke-4x: boolean
# Type --patch-lv2-lv1-peek-poke-4x: boolean
# Type --patch-lv2-npdrm-ecdsa-check: boolean
# Type --patch-lv2-SC36-4x: boolean
# Type --patch-misc-rogero-patches: boolean
# Type --patch-lv2-payload-hermes-4x: boolean
# Type --patch-spkg-ecdsa-check: boolean
# Type --patch-sppverifier-ecdsa-check: boolean
# Type --patch-sputoken-ecdsa-check: boolean
# Type --patch-RSOD-bypass: boolean

namespace eval ::patch_cos {
	
	# just create empty globals for the binary search/replace/offset strings
	set ::patch_cos::search ""
	set ::patch_cos::replace ""
	set ::patch_cos::offset 0
	set ::patch_cos::mask 0
    array set ::patch_cos::options {	
		--patch-lv0-nodescramble-lv1ldr false
		--patch-lv0-ldrs-ecdsa-checks true
		--patch-lv1-peek-poke true
		--patch-lv1-remove-lv2-protection true
		--patch-lv1-coreos-hash-check true
	    --patch-lv1-sysmgr-disable-integrity-check true
		--patch-lv2-peek-poke-4x true
        --patch-lv2-lv1-peek-poke-4x true
        --patch-lv2-npdrm-ecdsa-check true
		--patch-lv2-SC36-4x true
		--patch-misc-rogero-patches true
        --patch-lv2-payload-hermes-4x true		
		--patch-spkg-ecdsa-check true
		--patch-sppverifier-ecdsa-check true
		--patch-sputoken-ecdsa-check true
		--patch-RSOD-bypass true
    }

    proc main { } {
	
		set embd [file join dev_flash vsh etc layout_factor_table_272.txt]		
		
		## ---------------------- SET 'EXTERNALS' HERE ------------------
		## first see if "customize_firmware" task is even selected, if so,
		## set the "embed" param to the embedded app		
		set hermes_enabled false
		set embedded_app ""
		set installpkg_enabled false
		set addpkgmgr_enabled false
		set addhbseg_enabled false
		set addemuseg_enabled false
		set patchpkgfiles_enabled false
		set patchapphome_enabled false		
		
		if {[info exists ::patch_cos::options(--patch-lv2-payload-hermes-4x)]} {
			set hermes_enabled $::patch_cos::options(--patch-lv2-payload-hermes-4x) }
		if {[info exists ::customize_firmware::options(--customize-embedded-app)]} {
			set embedded_app ${::customize_firmware::options(--customize-embedded-app)} }				
		if {[info exists ::patch_xmb::options(--add-install-pkg)]} {
			set installpkg_enabled $::patch_xmb::options(--add-install-pkg) }	
		if {[info exists ::patch_xmb::options(--add-pkg-mgr)]} {
			set addpkgmgr_enabled $::patch_xmb::options(--add-pkg-mgr) }
		if {[info exists ::patch_xmb::options(--add-hb-seg)]} {
			set addhbseg_enabled $::patch_xmb::options(--add-hb-seg) }
		if {[info exists ::patch_xmb::options(--add-emu-seg)]} {
			set addemuseg_enabled $::patch_xmb::options(--add-emu-seg) }
		if {[info exists ::patch_xmb::options(--patch-package-files)]} {
			set patchpkgfiles_enabled $::patch_xmb::options(--patch-package-files) }
		if {[info exists ::patch_xmb::options(--patch-app-home)]} {
			set patchapphome_enabled $::patch_xmb::options(--patch-app-home) }			
		##  ----------------     END EXTERNALS -------------------------		
        
        
		# begin by calling the main function to go through
		# all the patches
		::patch_cos::Do_CoreOS_Patches $::CUSTOM_COSUNPKG_DIR        
		
		# if no options were selected to add the "*Install Pkg Files" elsewhere, 
		# install this package into dev_flash		
		if { $hermes_enabled } {
			if { ([expr {"$embedded_app" eq ""}]) && (!$installpkg_enabled) && (!$addpkgmgr_enabled) && (!$addhbseg_enabled)
			&& (!$addemuseg_enabled) && (!$patchpkgfiles_enabled) && (!$patchapphome_enabled) } {
				log "Copy standalone '*Install Package Files' app into dev_flash"
				#::modify_devflash_file $embd ::copy_ps3_game ${::CUSTOM_PS3_GAME}
				#::modify_devflash_file $embd ::patch_cos::install_pkg
				tk_messageBox -default ok -message "WARNING: Install PKG was not selected!" -icon warning
			}		
		}
    }		
	
	# --------------------------Do_CoreOS_Patches-------------------------------------------
	# this proc is for applying any patches to CORE_OS files, it is
	# expected that the "::patch_coreos_files" routine was already
	# called to extract all CORE_OS files, and return the "path"
	# of the unpackaged files
    proc Do_CoreOS_Patches {path} {
	
		# call the function to do any LV0 selected patches
		::patch_cos::Do_LV0_Patches $path					
		
		if {${::NEWMFW_VER} < "3.60"} { set self "lv1ldr" } else { set self "lv1ldr.self" }
		set file [file join $path $self]		
		# base function to decrypt the "self" to "elf" for patching
        ::modify_self_file $file ::patch_cos::Do_LV1LDR_Patches		
		
		if {${::NEWMFW_VER} < "3.60"} { set self "lv2ldr" } else { set self "lv2ldr.self" }
		set file [file join $path $self]		
		# base function to decrypt the "self" to "elf" for patching
        ::modify_self_file $file ::patch_cos::Do_LV2LDR_Patches		
		
		if {${::NEWMFW_VER} < "3.60"} { set self "isoldr" } else { set self "isoldr.self" }
		set file [file join $path $self]		
		# base function to decrypt the "self" to "elf" for patching
        ::modify_self_file $file ::patch_cos::Do_ISOLDR_Patches		
		
		if {${::NEWMFW_VER} < "3.60"} { set self "appldr" } else { set self "appldr.self" }
		set file [file join $path $self]		
		# base function to decrypt the "self" to "elf" for patching
        ::modify_self_file $file ::patch_cos::Do_APPLDR_Patches
		
		# call the function to do any LV1 selected patches				
		set self "lv1.self"
		set file [file join $path $self]		
		::modify_self_file $file ::patch_cos::Do_LV1_Patches		
		
		# call the function to do any LV2 selected patches
		set self "lv2_kernel.self"
		set file [file join $path $self]		
		::modify_self_file $file ::patch_cos::Do_LV2_Patches
	
		# call the function to do any other OS-file selected patches
		::patch_cos::Do_Misc_OS_Patches $path
					
	}
	### ------------------------------------- END:    Do_CoreOS_Patches{} --------------------------------------------- ###	
	

	# --------------------------  BEGIN:  Do_LV0_Patches   ------------------------------------------------------------ ### 
	#
	# This proc is for applying any patches to LV0
	#
	#
	proc Do_LV0_Patches {path} {
		
		log "Applying LV0 patches...."									
		# if "lv0-LV1LDR descramble" patch is enabled, patch in "lv0.elf"
		# ** LV0 IS ONLY SCRAMBLED IN OFW VERSIONS 3.65+ **
        if {$::patch_cos::options(--patch-lv0-nodescramble-lv1ldr)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			#
			# verified OFW ver. 3.56 - 4.55+
			# OFW 3.65 == 0x279A8 (0x80079A8)			
			# OFW 3.70 == 0x27A58 (0x8007A58)  
			# OFW 4.00 == 0x27A58 (0x8007A58) 
			# OFW 4.46 == 0x27AD0 (0x8007AD0)
			# OFW 4.55 == 0x27AD0 (0x8007AD0)			
			if {${::NEWMFW_VER} >= "3.65"} {
			
				log "Patching Lv0 to disable LV1LDR descramble"
				set self "lv0.elf"
				set file [file join $path $self]			
				set ::FLAG_NO_LV1LDR_CRYPT 1			
			
				set search  "\x64\x84\xB0\x00\x48\x00\x00\xFC\xE8\x61\x00\x70\x80\x81\x00\x7C\x48\x00\x09\xB1"
				set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00" ;# <-- mask off the bits/bytes to ignore				
				set replace "\x60\x00\x00\x00"												;# ^^ patch starts here 
				set offset 16						
				# PATCH THE ELF BINARY
				catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"     
				
			} else {	
				log "SKIPPING LV0-DESCRAMBLE PATCH, LV0 is NOT scrambled in FW below 3.65...."				
			}
        }		
		log "Done LV0 patches...."
	}
	### ------------------------------------- END:    Do_LV0_Patches{} --------------------------------------------- ### 
	
	
	
	# --------------------------  BEGIN:  Do_LV1LDR_Patches   -------------------------------------------------------### 
	#
	# This proc is for applying any patches to LV1 LOADER
	#
	#
	proc Do_LV1LDR_Patches {file} {	
	
		log "Applying LV1LDR patches...."			
		#if "--patch-lv0-ldrs-ecdsa-checks" enabled, patch it
		if {$::patch_cos::options(--patch-lv0-ldrs-ecdsa-checks)} {					
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x81A8 (0x1ACA8)			
			# OFW 3.70 == 0x6E48 (0x19948)  
			# OFW 4.00 == 0x6E50 (0x19950) 
			# OFW 4.46 == 0x6EB8 (0x199C4)
			# OFW 4.50 == 0x6F48 (0x199B8)
			# OFW 4.55 == 0x6F48 (0x199B8)
			log "Patching 4.xx LV1LDR ECDSA CHECKS......"      				
            set search  "\x0C\x00\x01\x85\x34\x01\x40\x80\x1C\x10\x00\x81\x3F\xE0\x02\x83"								
            set replace "\x40\x80\x00\x03"				
            set offset 12	
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"     			
		}	
		log "Done LV1LDR patches...."	
	}
	#
	### ------------------------------------- END:    Do_LV1LDR_Patches{} ------------------------------------------ ###
	
	
	# --------------------------  BEGIN:  Do_LV2LDR_Patches   -------------------------------------------------------### 
	#
	# This proc is for applying any patches to LV2 LOADER
	#
	#
	proc Do_LV2LDR_Patches {file} {	
	
		log "Applying LV2LDR patches...."	
		#if "--patch-lv0-ldrs-ecdsa-checks" enabled, patch it
		if {$::patch_cos::options(--patch-lv0-ldrs-ecdsa-checks)} {	
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #  
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x43C0 (0x16EC0)			
			# OFW 3.70 == 0x4458 (0x16F58)  
			# OFW 4.00 == 0x47F0 (0x172F0) 
			# OFW 4.46 == 0x47E8 (0x172E8)
			# OFW 4.50 == 0x47E8 (0x172E8)
			log "Patching 4.xx LV2LDR ECDSA CHECKS......"						            
            set search  "\x0C\x00\x01\x85\x34\x01\x40\x80\x1C\x10\x00\x81\x3F\xE0\x02\x83"
            set replace "\x40\x80\x00\x03"
            set offset 12
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"  
		}				
		log "Done LV2LDR patches...."	
	}
	#
	### ------------------------------------- END:    Do_LV2LDR_Patches{} ------------------------------------------ ###
	
	
	
	# --------------------------  BEGIN:  Do_ISOLDR_Patches   -------------------------------------------------------### 
	#
	# This proc is for applying any patches to ISO LOADER
	#
	#
	proc Do_ISOLDR_Patches {file} {	
	
		log "Applying ISOLDR patches...."	
		#if "--patch-lv0-ldrs-ecdsa-checks" enabled, patch it
		if {$::patch_cos::options(--patch-lv0-ldrs-ecdsa-checks)} {	
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> # 
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x49F0 (0x2A170)			
			# OFW 3.70 == 0x2750 (0x27ED0)  
			# OFW 4.00 == 0x2750 (0x27ED0) 
			# OFW 4.46 == 0x2898 (0x28018)
			# OFW 4.50 == 0x2898 (0x28018)
			log "Patching 4.xx ISOLDR ECDSA CHECKS......"       			
            set search  "\x0C\x00\x01\x85\x34\x01\x40\x80\x1C\x10\x00\x81\x3F\xE0\x02\x83"
            set replace "\x40\x80\x00\x03"
            set offset 12	
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]" 
		}				
		log "Done ISOLDR patches...."	
	}
	#
	### ------------------------------------- END:    Do_ISOLDR_Patches{} ------------------------------------------ ###
	
	
	# --------------------------  BEGIN:  Do_APPLDR_Patches   -------------------------------------------------------### 
	#
	# This proc is for applying any patches to ISO LOADER
	#
	#
	proc Do_APPLDR_Patches {file} {	
	
		log "Applying APPLDR patches...."	
		#if "--patch-lv0-ldrs-ecdsa-checks" enabled, patch it
		if {$::patch_cos::options(--patch-lv0-ldrs-ecdsa-checks)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #	
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x9F60 (0x1CA60)			
			# OFW 3.70 == 0x56B0 (0x181B0)  
			# OFW 4.00 == 0x5778 (0x18278) 
			# OFW 4.46 == 0x5740 (0x18240)
			log "Patching 4.xx APPLDR ECDSA CHECKS......"			
            set search  "\x0C\x00\x01\x85\x34\x01\x40\x80\x1C\x10\x00\x81\x3F\xE0\x02\x83"
            set replace "\x40\x80\x00\x03"
            set offset 12
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]" 
		}				
		log "Done APPLDR patches...."	
	}
	#
	### ------------------------------------- END: Do_APPLDR_Patches{} ------------------------------------------ ###
	
	
	
	# --------------------------  BEGIN:  Do_LV1_Patches   --------------------------------------------------------- ### 
	#
	# This proc is for applying any patches to LV1
	#
	#	
	proc Do_LV1_Patches {file} {		
		
		log "Applying LV1 patches...."		
		
		# if "lv1-peek-poke" enabled, patch it
		if {$::patch_cos::options(--patch-lv1-peek-poke)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x1225E8 (0x3025E8)
			# OFW 3.60: 0x123DB4 (0x303DB4			
			# OFW 4.30: 0x1299C0 (0x3099C0)
			# OFW 4.46: 0x1299C0 (0x3099C0)		
			# OFW 4.55: 0x129E48 (0x309E48)	
            log "Patching LV1 hypervisor - peek/poke support(1189356) part 1/2"         
            set search    "\x38\x00\x00\x00\x64\x00\xFF\xFF\x60\x00\xFF\xEC\xF8\x03\x00\xC0"
	        append search "\x4E\x80\x00\x20\x38\x00\x00\x00"
            set replace   "\xE8\x83\x00\x18\xE8\x84\x00\x00\xF8\x83\x00\xC8"         
			set offset 4
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"                
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x1225F8 (0x3025F8)
			# OFW 3.60: 0x123DC4 (0x303DC4			
			# OFW 4.30: 0x1299D0 (0x3099D0)
			# OFW 4.46: 0x1299D0 (0x3099D0)	
			# OFW 4.55: 0x129E60 (0x3099D0)	
			log "Patching LV1 hypervisor - peek/poke support(1189356) part 2/2" 
            set search    "\x4E\x80\x00\x20\x38\x00\x00\x00\x64\x00\xFF\xFF\x60\x00\xFF\xEC"
	        append search "\xF8\x03\x00\xC0\x4E\x80\x00\x20\xE9\x22"
            set replace   "\xE8\xA3\x00\x20\xE8\x83\x00\x18\xF8\xA4\x00\x00"         
			set offset 8
			set mask 0			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"                    
        }
		#if "lv1-remove-lv2-protection" enabled, patch it
		if {$::patch_cos::options(--patch-lv1-remove-lv2-protection)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x21D0B8 (0x44D0B8)
			# OFW 3.60: 0x21D0D4 (0x44D0D4)			
			# OFW 4.30: 0x23A998 (0x44A998)
			# OFW 4.46: 0x23A998 (0x44A998)	
			# OFW 4.55: 0x23AAA0 (0x44AAA0)	
            log "Patching LV1 hypervisior to remove LV2 protection"            
            set search  "\x2F\x83\x00\x00\x38\x60\x00\x01\x41\x9E\x00\x20\xE8\x62\x8A\xB8\x48\x01\xE6\x35"
			set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\x00\x00\x00\xFF\x00\x00\x00" ;# <-- mask off the bits/bytes to ignore	
            set replace "\x48\x00"                      ;# ^^ patch starts here
            set offset 8			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"                         
        }
		# if "--patch-lv1-coreos-hash-check" enabled, patch it		
        if {$::patch_cos::options(--patch-lv1-coreos-hash-check)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x2C1FA0
			# OFW 3.60: 0x2C21CC
			# OFW 4.46: 0x2DFA78
			# OFW 4.55: 0x2DFA70
            log "Patch CoreOS Hash check. Product mode always on (downgrader) (2891684)"           		               
			set search  "\x88\x18\x00\x36\x2F\x80\x00\xFF\x41\x9E\x00\x1C\x7F\x63\xDB\x78\xE8\xA2\x85\x78"	
			set mask	"\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00" ;# <-- mask off the bits/bytes to ignore	
            set replace "\x60\x00\x00\x00"              ;# ^^ patch starts here
			set offset 8			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"                       
        }
		# if "--patch-lv1-sysmgr-disable-integrity-check" enabled, patch it		
        if {$::patch_cos::options(--patch-lv1-sysmgr-disable-integrity-check)} {	
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x21D0A0 (0x44D0A0)
			# OFW 3.60 == 0x21D0BC (0x44D0BC)
			# OFW 4.46 == 0x23A994 (0x44A994)   
			# OFW 4.55 == 0x23A99C (0x44A99C)   			
            log "Patching System Manager to disable integrity check (OtherOS++/downgrader) (2216116)"            
            set search  "\x38\x60\x00\x01\xF8\x01\x00\x90\x88\x1F\x00\x00\x2F\x80\x00\x00\x40\x9E\x00\x48\x48\x00\xE0\x81"	
			set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\x00\x00\x00" ;# <-- mask off the bits/bytes to ignore				
            set replace "\x60\x00\x00\x00"																;# ^^ patch starts here
			set offset 20            
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]" 
        }
		log "Done LV1 patches...."	
	}
	### ------------------------------------- END:    Do_LV1_Patches{} --------------------------------------------- ###  				
	
	
	# --------------------------  BEGIN:  Do_LV2_Patches   --------------------------------------------------------- ### 
	#
	# This proc is for applying any patches to the "LV2" self file
	#
	#
	proc Do_LV2_Patches {file} {
	
		log "Applying LV2 patches...."	
		set verbosemode no
		# if verbose mode enabled
		if { $::options(--task-verbose) } {
			set verbosemode yes
		}
		array set hermes_payload_data {
			--jmpspot_pattern ""			
			--jmpspot_offset ""
			--payloadspot_pattern ""
			--payloadspot_address ""		
			--patch1_data ""
			--patch2_data ""
			--patch3_data ""
			--patch4_data ""
			--patch5_data ""
			--patch6_data ""
			--patch7_data ""
		}		
		
		#### ---------------------------------------------------- BEGIN: 4.XX PATCHES AREA ----------------------------------------------- ####
		####
		#				
		##  set the filename here, and prepend the "path"		
		
		set pop_warning 0	
		# check for any erroneous settings, and throw up message boxes if so
		if {$::patch_cos::options(--patch-lv2-peek-poke-4x)} {
			if {![info exists ::patch_lv1::options(--patch-lv1-mmap)]} {
				if {!$::patch_cos::options(--patch-lv1-remove-lv2-protection)} {					
					set pop_warning 1
				}
			} elseif {!$::patch_lv1::options(--patch-lv1-mmap)} {
				if {!$::patch_cos::options(--patch-lv1-remove-lv2-protection)} {					
					set pop_warning 1
				}
            }
			if {$pop_warning == 1} {
					log "WARNING: You enabled Peek&Poke without enabling LV1 mmap or LV2 protection patching." 1
					log "WARNING: Patching LV1 mmap or deactivated LV2 protection is necessary for Poke to function." 1
					tk_messageBox -default ok -message "WARNING: You enabled Peek&Poke without enabling LV1 mmap or LV2 protection patching, \
					Patching LV1 mmap or deactivated LV2 protection is necessary for Poke to function." -icon warning			
			}
		}
		# if "--patch-lv2-peek-poke-4x" enabled, do patch
		if {$::patch_cos::options(--patch-lv2-peek-poke-4x)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x65F68 (0x55F68)
			# OFW 3.60: 0x66930 (0x56930)			
			# OFW 4.30: 0x67234 (0x57234)
			# OFW 4.46: 0x66188 (0x56188)	
			# OFW 4.55: 0x66448 (0x56448)	
			log "Patching LV2 peek&poke for 4.xx CFW - part 1/2"				 
			set search   "\x3F\xE0\x80\x01\x63\xFF\x00\x3E\x4B\xFF\xFF\x0C\x83\xBC\x00\x78\x2F\x9D\x00\x00"
			set mask	 "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" ;# <-- mask off the bits/bytes to ignore	
			set replace  "\x3B\xE0\x00\x00";#patch starts here
			set offset 4			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    		 					
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x65EA4 (0x55EA4)
			# OFW 3.60: 0x6686C (0x5686C)			
			# OFW 4.30: 0x67174 (0x57174)
			# OFW 4.46: 0x660C4 (0x560C4)	
			# OFW 4.55: 0x66384 (0x56384)	
			log "Patching LV2 peek&poke for 4.xx CFW - part 2/2"	
			set search  "\x3F\xE0\x80\x01\x2F\x84\x00\x02\x63\xFF\x00\x3D\x41\x9E\xFF\xD4\x38\xDE\x00\x07\x88\x1E\x00\x07"
			set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" ;# <-- mask off the bits/bytes to ignore	
			set replace "\x60\x00\x00\x00"								;# ^^ patch starts here
			set offset 12			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    			 
		}
		# if "--patch-lv2-lv1-peek-poke-4x" enabled, do patch
		if {$::patch_cos::options(--patch-lv2-lv1-peek-poke-4x)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x10F00 (0xF00) ** PATCH @0x1170C **
			# OFW 3.60: 0x10F00 (0xF00) ** PATCH @0x1170C **		
			# OFW 4.30: 0x10F00 (0xF00) ** PATCH @0x1170C **
			# OFW 4.46: 0x10F00 (0xF00)	** PATCH @0x1170C **
			# OFW 4.55: 0x10F00 (0xF00)	** PATCH @0x1170C **
			log "Patching LV1 peek&poke call permission for LV2 into LV2 - part 1/2"
			# 7C 71 43 A6 7C 92 43 A6 48 00 00 00 00 00 00 00
			# 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
			# 7C 71 43 A6 7C 92 43 A6 7C B3 43 A6 7C 7A 02 A6......
			set search     "\x7C\x71\x43\xA6\x7C\x92\x43\xA6\x48\x00\x00\x00\x00\x00\x00\x00"
			append search  "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
			append search  "\x7C\x71\x43\xA6\x7C\x92\x43\xA6\x7C\xB3\x43\xA6\x7C\x7A\x02\xA6"
			set replace    "\xE8\x63\x00\x00\x4E\x80\x00\x20\xF8\x83\x00\x00\x4E\x80\x00\x20"
			append replace "\x7C\x08\x02\xA6\xF8\x01\x00\x10\x39\x60\x00\xB6\x44\x00\x00\x22"
			append replace "\x7C\x83\x23\x78\xE8\x01\x00\x10\x7C\x08\x03\xA6\x4E\x80\x00\x20"
			append replace "\x7C\x08\x02\xA6\xF8\x01\x00\x10\x39\x60\x00\xB7\x44\x00\x00\x22"
			append replace "\x38\x60\x00\x00\xE8\x01\x00\x10\x7C\x08\x03\xA6\x4E\x80\x00\x20"
			append replace "\x7C\x08\x02\xA6\xF8\x01\x00\x10\x7D\x4B\x53\x78\x44\x00\x00\x22"
			append replace "\xE8\x01\x00\x10\x7C\x08\x03\xA6\x4E\x80\x00\x20\x80\x00\x00\x00"
			append replace "\x00\x00\x17\x0C\x80\x00\x00\x00\x00\x00\x17\x14\x80\x00\x00\x00"
			append replace "\x00\x00\x17\x1C\x80\x00\x00\x00\x00\x00\x17\x3C\x80\x00\x00\x00"
			append replace "\x00\x00\x17\x5C"
			set offset 2060
			set mask 0
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    			 					
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x355DE5 (0x345DE5) ** PATCH @0x3565A0 **
			# OFW 3.60: 0x35D05D (0x34D05D) ** PATCH @0x35D818 **		
			# OFW 4.30: 0x36D425 (0x35D425) ** PATCH @0x36DC10 **
			# OFW 4.46: 0x36E0A5 (0x35E0A5)	** PATCH @0x36E890 **
			# OFW 4.50: 0x36E915 (0x35E915)	** PATCH @0x36F100 **
			# OFW 4.55: 0x371EC5 (0x361EC5)	** PATCH @0x3726B0 **
			log "Patching LV1 peek&poke call permission for LV2 into LV2 - part 2/2"
			# code pattern at start of 'vector table', same across all FWs
			# for >= 3.70 FW, offset is 0x7EB (2027)
			# for < 3.70 FW, offset is 0x7BB (1979)			
			set search     "\x83\x86\x5C\xCB\x37\x6F\x5D\x5C\x43\x93\xA4\xBA\x53\x35\x90\x03"			
			set replace    "\x80\x00\x00\x00\x00\x00\x17\x78\x80\x00\x00\x00\x00\x00\x17\x80"
			append replace "\x80\x00\x00\x00\x00\x00\x17\x88\x80\x00\x00\x00\x00\x00\x17\x90"
			append replace "\x80\x00\x00\x00\x00\x00\x17\x98"
			set mask 0
			if {${::NEWMFW_VER} >= "3.70"} {
				set offset 2027
			} else {
				set offset 1979
			}
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    			   
		}
		# if "-patch-lv2-npdrm-ecdsa-check" enabled, do patch
		if {$::patch_cos::options(--patch-lv2-npdrm-ecdsa-check)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #					
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x (0x)  ** doesn't exist **
			# OFW 3.60: 0x (0x)  ** doesn't exist **
			# OFW 4.00: 0x6A260 (0x5A260)
			# OFW 4.21: 0x6A2A8 (0x5A2A8)
			# OFW 4.46: 0x69348 (0x59348)
			# OFW 4.55: 0x69AF8 (0x59AF8)
			
			## since patch is unsure for OFW <= 3.55, only patch if > 3.55
			if {${::NEWMFW_VER} >= "3.60"} {
				log "Patching NPDRM ECDSA check disabled"						
				set search	   "\xE9\x22\x99\x90\x7C\x08\x02\xA6\xF8\x21\xFF\x21\xF8\x01\x00\xF0\xFB\xE1\x00\xD8\xFB\xA1\x00\xC8\xE8\x09\x00\x00\x7C\x9F\x23\x78"
				set mask	   "\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
				append search  "\xFB\xC1\x00\xD0\x54\x00\x07\xFE\x2F\x80\x00\x00"
				append mask    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
				set replace    "\x38\x60\x00\x00\x4E\x80\x00\x20"
				set offset 0				
				# PATCH THE ELF BINARY
				catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"  
				
			} else {
				log "Skipping NPDRM ECDSA Patch, not supported for OFW < 3.60, continuing!!\n"				
			}
		}
		# if "--patch-lv2-SC36-4x" enabled, do patch
		if {$::patch_cos::options(--patch-lv2-SC36-4x)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x65F14 (0x55F14)
			# OFW 3.60: 0x668DC (0x568DC)
			# OFW 4.30: 0x671E0 (0x571E0)
			# OFW 4.46: 0x66134 (0x56134)
			# OFW 4.55: 0x663F4 (0x563F4)
			log "Patching LV2 with SysCall36 4.xx CFW part 1/3"			
			set search     "\x41\x9E\x00\xD8\x41\x9D\x00\xC0\x2F\x84\x00\x04\x40\x9C\x00\x48"			
			set replace    "\x60\x00\x00\x00\x2F\x84\x00\x04\x48\x00\x00\x98"
			set offset 4
			set mask 0
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    			
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #						
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x8AF68 (0x7AF68)
			# OFW 3.60: 0x6A19C (0x5A19C)
			# OFW 4.30: 0x6ABA0 (0x5ABA0)
			# OFW 4.46: 0x69AF8 (0x59AF8)
			# OFW 4.55: 0x6A2F0 (0x5A2F0)
			log "Patching LV2 with SysCall36 4.xx CFW part 2/3"	
		#	set search  "\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\x20\xE8\x61\x01\x38"	;# -- OFW 3.55 --
		#	set search  "\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\x70\xE8\x61\x01\x88"	;# -- OFW 4.46 --	
			set search  "\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\xAC\xE8\x61\x01\x88"	;# -- OFW 4.55 --
			set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\xFF\xFF\xFF\x0F" ;# <-- mask off the bits/bytes to ignore
			set replace "\x60\x00\x00\x00"
			set offset 8			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    		 					
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #					
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x8AF74 (0x7AF74)
			# OFW 3.60: 0x6A1B0 (0x5A1B0)
			# OFW 4.30: 0x6ABB4 (0x5ABB4)
			# OFW 4.46: 0x69B0C (0x59B0C)
			# OFW 4.55: 0x6A304 (0x5A304)
			log "Patching LV2 with SysCall36 4.xx CFW part 3/3"					
		#	set search	"\x54\x63\x06\x3E\x2F\x83\x00\x00\x60\x00\x00\x00\xE8\x61\x01\x38\x4B\xFF\xF4\xED\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\x00" ;# -- OFW 3.55 --
		#	set search  "\x54\x63\x06\x3E\x2F\x83\x00\x00\x60\x00\x00\x00\xE8\x61\x01\x88\x4B\xFF\xF3\x31\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\x00" ;# -- OFW 4.46 --
			set search  "\x54\x63\x06\x3E\x2F\x83\x00\x00\x60\x00\x00\x00\xE8\x61\x01\x88\x4B\xFF\xF2\xA9\x54\x63\x06\x3E\x2F\x83\x00\x00\x41\x9E\x00\x00" ;# -- OFW 4.55 --		
			set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00" ;# <-- mask off bytes
			set replace "\x60\x00\x00\x00"
			set offset 28			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"    			 
		}
		log "Applying MISC LV2 patches (QA Flag patches???)...."	
		if {$::patch_cos::options(--patch-misc-rogero-patches)} {	
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55 == 0x29A404 (0x28A404)
			# OFW 3.60 == 0x29AC6C (0x28AC6C)
			# OFW 3.70 == 0x2A0188 (0x290188)  
			# OFW 4.46 == 0x2A7314 (0x297314)
			# OFW 4.50 == 0x27F608 (0x26F608)
			# OFW 4.55 == 0x281040 (0x271040)
			log "Patching LV2_KERNEL with Rogero QA Flag patch??"						 
			set search    "\x7C\x09\xFE\x76\x7D\x23\x02\x78\x7C\x69\x18\x50\x38\x63\xFF\xFF"
			append search "\x78\x63\x0F\xE0\x4E\x80\x00\x20\x80\x03\x02\x6C"
			set replace   "\x38\x60\x00\x00\x7C\x63\x07\xB4\x4E\x80\x00\x20"
			set offset 24 
			set mask 0			
			# PATCH THE ELF BINARY
            catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"  		
		}
		# if "--patch-lv2-payload-hermes-4x" enabled, then patch
		if {$::patch_cos::options(--patch-lv2-payload-hermes-4x)} {								
			
			## ------------------------------------------------------------------------------------------------------- ##
			## ------------------------------- FIND THE OFFSETs FOR THE HERMES PAYLOAD SETUP ------------------------- ##
			## ------------------------------------------------------------------------------------------------------- ##			
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x2E8460 (0x2D8460)
			# OFW 3.60: 0x2EB940 (0x2DB940)
			# OFW 4.30: 0x2F9F98 (0x2E9F98)
			# OFW 4.46: 0x2FAA48 (0x2EAA48)
			# OFW 4.50: 0x2F9C48 (0x2E9C48)		
			## --- patch for "finding Hermes payload install(payload spot) location...." --- ##			
			set search 	"\x23\x20\x49\x6E\x74\x65\x72\x72\x75\x70\x74\x28\x65\x78\x63\x65"		;# '# Interrupt' string
			set hermes_payload_data(--payloadspot_pattern) $search		
			set replace ""			
			set offset 8						
			
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.60 - 4.50+
			# OFW 3.55 == 0x2C3274 (0x2B3274)
			# OFW 3.60 == 0x2BFA90 (0x2AFA90)
			# OFW 3.70 == 0x2CC250 (0x2BC250)  
			# OFW 4.46 == 0x2D47B0 (0x2C47B0)
			# OFW 4.50 == 0x2ADD20 (0x29DD20)				
			## --- patch for "finding Hermes payload intercept(jmp spot) location...." --- ##	
			set search    "\xF8\x21\xFF\x61\x7C\x08\x02\xA6\xFB\x81\x00\x80\xFB\xA1\x00\x88"					
			append search "\xFB\xE1\x00\x98\xFB\x41\x00\x70\xFB\x61\x00\x78\xF8\x01\x00\xB0"					
			append search "\x7C\x9C\x23\x78\x7C\x7D\x1B\x78\x4B"			
			set hermes_payload_data(--jmpspot_pattern) $search								
			set replace ""
			set offset 0   									
			
			## go and calculate all the 'hermes payload' jmp spot, install spot, etc data
			catch_die {::patch_cos::SetupHermesPayload $file hermes_payload_data} "Unexpected error setting up Hermes Payload!  Exiting\n"			
			
			# verify the 'hermes_payload_data{}' array, make
			# sure no values are emtpy
			foreach key [array names hermes_payload_data] {
				if {$hermes_payload_data($key) == ""} {
					die "Error, missing data for Hermes payload setup, exiting!\n"
				}
			}			
			#
			## ------------------------------------------------------------------------------------------------------- ##	
			## ------------------------------- DONE FINDING OFFSETs FOR THE HERMES PAYLOAD SETUP --------------------- ##			
			## ------------------------------------------------------------------------------------------------------- ##
			
			## ---------------------- ORG HERMES PAYLOAD ---------------------- 
			#\xF8\x21\xFF\x61\x7C\x08\x02\xA6\xFB\x81\x00\x80\xFB\xA1\x00\x88
			#\xFB\xE1\x00\x98\xFB\x41\x00\x70\xFB\x61\x00\x78\xF8\x01\x00\xB0
			#\x7C\x9C\x23\x78\x7C\x7D\x1B\x78\x3B\xE0\x00\x01\x7B\xFF\xF8\x06
			#\x67\xE4\x00\x2E\x60\x84\x9C\xBC\x38\xA0\x00\x02\x4B\xD6\x3A\x0D
			#\x28\x23\x00\x00\x40\x82\x00\x28\x67\xFF\x00\x2E\x63\xFF\x9C\xCC
			#\xE8\x7F\x00\x00\x28\x23\x00\x00\x41\x82\x00\x14\xE8\x7F\x00\x08
			#\x38\x9D\x00\x09\x4B\xD6\x39\x91\xEB\xBF\x00\x00\x7F\xA3\xEB\x78
			#\x4B\xFB\x40\x8C\x2F\x61\x70\x70\x5F\x68\x6F\x6D\x65\x00\x00\x00
			#\x00\x00\x00\x00\x80\x00\x00\x00\x00\x2E\x9C\xDC\x80\x00\x00\x00
			#\x00\x2E\x9C\xEA\x2F\x64\x65\x76\x5F\x66\x6C\x61\x73\x68\x2F\x70
			#\x6B\x67\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00
			
			set got_data 0
			# PATCH1: extract out the bytes of the 'string1' (patch1)
			set temp [format %llX $hermes_payload_data(--patch1_data)]				
			set temp [binary format H* $temp]			
			if {[string length $temp] == 8} {
				set p1byte4 [string index $temp 4]
				set p1byte3 [string index $temp 5]
				set p1byte2 [string index $temp 6]
				set p1byte1 [string index $temp 7]
				incr got_data 1
			} 			
			# PATCH2: extract out the bytes of the 'payload_branch_address1' (patch2)
			set temp [format %.8X $hermes_payload_data(--patch2_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 4} {
				set p2byte4 [string index $temp 0]
				set p2byte3 [string index $temp 1]
				set p2byte2 [string index $temp 2]
				set p2byte1 [string index $temp 3]
				incr got_data 1
			} 
			# PATCH3: extract out the bytes of the 'string2' (patch3)
			set temp [format %llX $hermes_payload_data(--patch3_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 8} {
				set p3byte4 [string index $temp 4]
				set p3byte3 [string index $temp 5]
				set p3byte2 [string index $temp 6]
				set p3byte1 [string index $temp 7]
				incr got_data 1
			} 
			# PATCH4: extract out the bytes of the 'payload_branch_address2' (patch4)
			set temp [format %.8X $hermes_payload_data(--patch4_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 4} {
				set p4byte4 [string index $temp 0]
				set p4byte3 [string index $temp 1]
				set p4byte2 [string index $temp 2]
				set p4byte1 [string index $temp 3]
				incr got_data 1
			}
			# PATCH5: extract out the bytes of the 'payload_branch_address3' (patch5)
			set temp [format %.8X $hermes_payload_data(--patch5_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 4} {
				set p5byte4 [string index $temp 0]
				set p5byte3 [string index $temp 1]
				set p5byte2 [string index $temp 2]
				set p5byte1 [string index $temp 3]
				incr got_data 1
			} 
			# PATCH6: extract out the bytes of the 'string2_address' (patch6)
			set temp [format %llX $hermes_payload_data(--patch6_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 8} {
				set p6byte8 [string index $temp 0]
				set p6byte7 [string index $temp 1]
				set p6byte6 [string index $temp 2]
				set p6byte5 [string index $temp 3]
				set p6byte4 [string index $temp 4]
				set p6byte3 [string index $temp 5]
				set p6byte2 [string index $temp 6]
				set p6byte1 [string index $temp 7]
				incr got_data 1
			}
			# PATCH7: extract out the bytes of the 'string3_address' (patch7)
			set temp [format %llX $hermes_payload_data(--patch7_data)]	
			set temp [binary format H* $temp]
			if {[string length $temp] == 8} {
				set p7byte8 [string index $temp 0]
				set p7byte7 [string index $temp 1]
				set p7byte6 [string index $temp 2]
				set p7byte5 [string index $temp 3]
				set p7byte4 [string index $temp 4]
				set p7byte3 [string index $temp 5]
				set p7byte2 [string index $temp 6]
				set p7byte1 [string index $temp 7]
				incr got_data 1
			}	
			# verify all hermes setup data was extracted from the array
			if {$got_data != 7} {
				die "Error, could not extract all data for Hermes payload setup, exiting!\n"
			}
			# now build the final 'hermes' payload, populate in all the patch
			# bytes calculated above
			log "Patching Hermes payload 4.xx into LV2"	
			set ACTUAL_HERMES_PAYLOAD_SIZE 0xB0	;# the actual exact size this payload must be
			set search $hermes_payload_data(--payloadspot_pattern)			
			set replace    	"\xF8\x21\xFF\x61\x7C\x08\x02\xA6\xFB\x81\x00\x80\xFB\xA1\x00\x88"
			append replace  "\xFB\xE1\x00\x98\xFB\x41\x00\x70\xFB\x61\x00\x78\xF8\x01\x00\xB0" 
			append replace  "\x7C\x9C\x23\x78\x7C\x7D\x1B\x78\x3B\xE0\x00\x01\x7B\xFF\xF8\x06"
			append replace  "\x67\xE4\x00$p1byte3\x60\x84$p1byte2$p1byte1\x38\xA0\x00\x02\x4B$p2byte3$p2byte2$p2byte1"		;# patches 1 & 2 in this line
			append replace  "\x28\x23\x00\x00\x40\x82\x00\x28\x67\xFF\x00$p3byte3\x63\xFF$p3byte2$p3byte1"					;# patch3 in this line
			append replace  "\xE8\x7F\x00\x00\x28\x23\x00\x00\x41\x82\x00\x14\xE8\x7F\x00\x08"
			append replace  "\x38\x9D\x00\x09\x4B$p4byte3$p4byte2$p4byte1\xEB\xBF\x00\x00\x7F\xA3\xEB\x78"					;# patch4 in this line
			append replace  "\x4B$p5byte3$p5byte2$p5byte1\x2F\x61\x70\x70\x5F\x68\x6F\x6D\x65\x00\x00\x00"					;# patch5 in this line
			append replace  "\x00\x00\x00\x00$p6byte8$p6byte7$p6byte6$p6byte5$p6byte4$p6byte3$p6byte2$p6byte1"				;# patch6 in this line
			append replace  "$p7byte8$p7byte7$p7byte6$p7byte5$p7byte4$p7byte3$p7byte2$p7byte1\x2F\x64\x65\x76\x5F\x66"		;# patch7 in this line
			append replace  "\x6C\x61\x73\x68\x2F\x70\x6B\x67\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"	
			set offset 8
			set mask 0
			
			# final sanity check to make sure 'hermes payload' data is exactly the right size
			if {[string length $replace] != $ACTUAL_HERMES_PAYLOAD_SIZE} { die "hermes payload appears to be corrupt, current length is invalid!" }			
			# PATCH THE ELF BINARY
			catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]" 				
			
			log "Patching Hermes payload jump to location...."				
			set search $hermes_payload_data(--jmpspot_pattern)			
			set replace   "\x48"			
			append replace $hermes_payload_data(--jmpspot_offset)
			set offset 0
			set mask 0
			# PATCH THE ELF BINARY
            catch_die {::patch_elf $file $search $offset $replace $mask} "Unable to patch self [file tail $file]"  	
		}		
		##
		#### ------------------------------------------------------  END:  4.XX PATCHES AREA ----------------------------------------------- ####				
		
		log "Done LV2 patches...."
	}
	### ------------------------------------- END:    Do_LV2_Patches{} ---------------------------------------------------------------------- ###  			
	
	
	
	# --------------------------  BEGIN:  Do_Misc_OS_Patches   --------------------------------------------------------- ### 
	#
	# This proc is for applying any patches any other OS specific files
	#
	#
	proc Do_Misc_OS_Patches {path} {	
			
		log "Applying OS Misc File patches...."						
		# if "--patch-spkg-ecdsa-check" is enabled, patch in "spu_pkg_rvk_verifier.self"
		if {$::patch_cos::options(--patch-spkg-ecdsa-check)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x3150 (0x38D0)
			# OFW 3.60: 0x3150 (0x38D0)
			# OFW 4.30: 0x3150 (0x38D0)
			# OFW 4.46: 0x3150 (0x38D0)
            log "Patching SPU_PKG_RVK verifier to disable ECDSA check"  
			set self "spu_pkg_rvk_verifier.self"
			set file [file join $path $self]			
          
		    set ::patch_cos::search  "\x04\x00\x2A\x03\x33\x7F\xD0\x80\x04\x00\x01\x82\x32\x00\x01\x00"
            set ::patch_cos::replace "\x40\x80\x00\x03"
			set ::patch_cos::offset 4			
			set ::patch_cos::mask 0
			# base function to decrypt the "self" to "elf" for patching
			::modify_self_file $file ::patch_cos::patch_elf	
        }		
		# if "--patch-sppverifier-ecdsa-check" is enabled, patch in "spp_verifier.self"
		if {$::patch_cos::options(--patch-sppverifier-ecdsa-check)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: 0x129C (0x199C)
			# OFW 3.60: 0x129C (0x199C)
			# OFW 4.30: 0x129C (0x199C)
			# OFW 4.46: 0x129C (0x199C)
            log "Patching SPP_VERIFIER to disable ECDSA check"  
			set self "spp_verifier.self"
			set file [file join $path $self]			          
			
			set ::patch_cos::search    "\x3F\xE0\x29\x04\x42\x54\xE8\x05\x40\xFF\xFF\x53\x33\x07\x95\x00"			
			set ::patch_cos::replace   "\x40\x80\x00\x03"
			set ::patch_cos::offset 12	
			set ::patch_cos::mask 0			
			# base function to decrypt the "self" to "elf" for patching
			::modify_self_file $file ::patch_cos::patch_elf	
        }
		# if "--patch-sputoken-ecdsa-check" is enabled, patch in "spu_token_processor.self"
		if {$::patch_cos::options(--patch-sputoken-ecdsa-check)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
			# (patch seems fine, NO mask req'd)
			#
			# verified OFW ver. 3.55 - 4.55+
			# OFW 3.55: *** does not exist in this version ***
			# OFW 3.60: 0x2B0 (0xA30)
			# OFW 4.30: 0x2B0 (0xA30)
			# OFW 4.46: 0x2B0 (0xA30)
            log "Patching SPU_TOKEN_PROCESSOR to disable ECDSA check" 			
			set self "spu_token_processor.self"
			set file [file join $path $self]			
          
			if {${::NEWMFW_VER} > "3.56"} {
				set ::patch_cos::search	   "\x12\x03\x42\x0B\x24\xFF\xC0\xD0\x04\x00\x01\xD0\x24\xFF\x80\xD1\x24\xFF\x40\xD2\x24\x00\x40\x80\x04\x00\x02\x52\x24\xFB\x80\x81"
				set ::patch_cos::mask	   "\xFF\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
				set ::patch_cos::replace   "\x40\x80\x00\x03\x35\x00\x00\x00"
				set ::patch_cos::offset 0				
				# base function to decrypt the "self" to "elf" for patching
				::modify_self_file $file ::patch_cos::patch_elf					
				
			} else {
				log "Skipping SPU_TOKEN ECDSA PATCH, not needed in this version!"
			}			
        }
		# if "--patch-RSOD-bypass" is enabled, patch in "dev_flash\vsh\module\basic_plugins.sprx"
		if {$::patch_cos::options(--patch-RSOD-bypass)} {
		
			if {${::NEWMFW_VER} >= "4.00"} {			
				log "Patching BASIC_PLUGINS.sprx to patch RSOD bypass"  
				set BASIC_PLUGINS [file join dev_flash vsh module basic_plugins.sprx]
				::modify_devflash_file $BASIC_PLUGINS ::patch_cos::patch_devflash_self	
				
			} else {
				log "Skipping RSOD bypass patch, doesn't seem to exist under OFW 4.00!"
			}
        }	
	}
	### ------------------------------------- END:    Do_Misc_OS_Patches{} --------------------------------------------- ###   
	
	
	### ------------------------------------------------------------------------------- ##
	### ---------------- MAIN PROC FOR CONFIGURING 'HERMES' PAYLOAD ------------------- ##
	##
	proc SetupHermesPayload {elf array} {
		upvar $array my_payload_data
		set verbosemode no
		# if verbose mode enabled
		if { $::options(--task-verbose) } {
			set verbosemode yes
		}				
		
		### ------------------------------------------------------------------------------------------------ ###
		### -------------------------- INITIAL ELF 32/64 HEADER DATA --------------------------------------- ###
		###																									 ###
		##   ** note:  Just setup both 32/64 bit ELF headers, just in case									  ##
		##             we need to use the 32-bit in the future 												  ##
		##             (in our case, LV2_KERNEL is always 64-bit)											  ##
		##   **																								  ##
		
		# read in the first 0x100 bytes of the ELF
		# file to verify/setup header bytes
		set fd [open $elf r]
		fconfigure $fd -translation binary 
        catch_die {set rawdata [read $fd 255]} "Error, could not read $elf->ELF header data! Exiting\n"
        close $fd     		
		
		set elf_header_32 [string range $rawdata 0 51] 
		set elf_header_64 [string range $rawdata 0 63] 
		binary scan $elf_header_32 Iu1cu1cu1cu1cu1cu1a7Su1Su1Iu1Iu1Iu1Iu1Iu1Su2Su2Su2Su2Su2Su2 \
									elmag elclass eldata elversion elosabi elabiver elpad \
									eltype elmachine elversion32 elentry32 elphoff32 elshoff32 \
									elflags32 elehsize32 elphentsize32 elphnum32 elshentsize32 elshnum32 elshstrndx32 
		binary scan $elf_header_64 Iu1cu1cu1cu1cu1cu1a7Su1Su1Iu1Wu1Wu1Wu1Iu1Su2Su2Su2Su2Su2Su2 \
									elmag elclass eldata elversion elosabi elabiver elpad \
									eltype elmachine elversion64 elentry64 elphoff64 elshoff64 \
									elflags64 elehsize64 elphentsize64 elphnum64 elshentsize64 elshnum64 elshstrndx64 																				
		
		# verify elf-magic is ".ELF",
		# verify lv2_kernel is 64-bit,
		# verify lv2_kernel is BIG-ENDIAN format
		if {$elmag != 2135247942} { die "ELF header is invalid!\n" }
		if {$elclass != 2} { die "ELF is NOT 64-bit, exiting!" }
		if {$eldata != 2} { die "ELF is NOT BIG-ENDIAN format, exiting!" }
		
		# now read in the 'ELF program header'
		catch_die {set elf_prog_header_64 [string range $rawdata $elphoff64 [expr $elphoff64+56]]} "Error, offset out of range!!"
		binary scan $elf_prog_header_64 Iu1Iu1Wu1Wu1Wu1Wu1Wu1Wu1 \
										ptype64 pflags64 poffset64 pvaddr64 ppaddr64 \
										pfilesz64 pmemsz64 palign64		
		
		# verify lv2_kernel 'ptype' is PT_LOAD (ie 0x01),
		# verify lv2_kernel 'flags' is Read & Execute
		if {$ptype64 != 1} { die "ELF is NOT PT_LOAD type, exiting!" }				
		if {$pflags64 != 5} { die "ELF is NOT Read/Execute, exiting!" }
		if {$pvaddr64 != $ppaddr64} { die "ELF Virtual Address is Not Equal to Physical Address, scripts now needs fixing!!!" }					
		
		# if verbose enabled, log the ELF 
		# vars read in
		if {$verbosemode eq yes} {
			log "Magic is:0x$elmag"
			log "Class is:0x[format %x $elclass]"
			log "Data is:0x[format %x $eldata]"
			log "Entry point is:0x[format %llx $elentry64]"
			log "Program Header offset is:0x[format %llx $elphoff64]"
			log "Section Header offset is:0x[format %llx $elshoff64]"
			log "Program Type is:0x[format %llx $ptype64]"
			log "Program Flags is:0x[format %llx $pflags64]"
			log "Program Begin FileOffset is:0x[format %llx $poffset64]"
			log "Program Virtual Addr is:0x[format %llx $pvaddr64]"
			log "Program Phys. Addr is:0x[format %llx $ppaddr64]\n"
		}
		###
		### -------------------------- DONE INITIAL ELF 32/64 HEADER PARSING ------------------------------- ###
		### ------------------------------------------------------------------------------------------------ ###						
		
		
		# all checks passed, setup the actual: 
		# 1) 64-bit LV2_KERNEL base address, and
		# 2) 64-bit LV2_KERNEL 'starting offset' from the ELF file
		set LV2_KERNEL_BASEADDR_64 $pvaddr64
		set LV2_KERNEL_PROGRAM_STARTOFFSET $poffset64
		
		# vars for setting up the hermes payload,
		# and the various offsets, etc				
		set hermes_payload_install_spot 0
		set hermes_payload_jmp_address 0
		set hermes_jmp_offset 0
		set offsetpatch ""

		set lv2_offset_branch1 59				;# 0x3B:  offset to 'branch#1' in hermes payload
		set hermes_payload_branch_address1 0	;# 0x.... 24-bit offset in hermes payload, to branch out function 1		
		set lv2_offset_branch2 99				;# 0x63:  offset to 'branch#2' in hermes payload
		set hermes_payload_branch_address2 0	;# 0x.... 24-bit offset in hermes payload, to branch out function 2
		set lv2_offset_ret_branch3 36			;# 0x24:  offset to return spot from branch#3		
		set lv2_offset_branch3 112				;# 0x70:  offset to 'branch#3' in hermes payload
		set hermes_payload_branch_address3 0	;# 0x.... 24-bit offset in hermes payload, to branch out function 3	
		set hermes_payload_branch_ret_address3 0	
		
		set hermes_payload_ptr_string2 132		;# 0x84:  offset in hermes payload, 64-bit pointer to string1 ('/app_home')
		set hermes_payload_ptr_string3 144		;# 0x90:  offset in hermes payload, 64-bit pointer to string2 ('/dev_flash/pkg')		
		
		set hermes_payload_offset_string1 116	;# 0x74:  offset in hermes payload to string1 ('/app_home')
		set hermes_payload_offset_string2 148   ;# 0x94:  offset in hermes payload to string2 ('/dev_flash/pkg')
		set hermes_payload_offset_string3 162	;# 0xA2:  offset in hermes payload to string3 ('')  ** i.e currently unused **											
		
	
	    # ----------------------------------------------------------------- #
		# -------------- FIND 'HERMES PAYLOAD INSTALL LOCATION ------------ #
		# ----------------------------------------------------------------- #
		# go and find the offset ONLY, to use for final install location		
		log "finding Hermes payload install location....(Hermes Setup 1/4)"	
		
		set search $my_payload_data(--payloadspot_pattern)
		set replace ""			
		set offset 8
		set mask 0
		# GRAB THE PATCH OFFSET VALUE ONLY
		set ::FLAG_PATCH_FILE_NOPATCH 1
		catch_die {set hermes_payload_install_spot [::patch_elf $elf $search $offset $replace $mask]} "Unable to patch self [file tail $elf]" 
		set hermes_payload_install_spot [expr $LV2_KERNEL_BASEADDR_64 + $hermes_payload_install_spot - $LV2_KERNEL_PROGRAM_STARTOFFSET]				
		
		# -------------- FIND 'HERMES PAYLOAD' JMP TO ADDRESS ------------- #
		# set the 'flag' to ONLY find the patch offset initially, as we want
		# to find the offset first, calculate the jmp offset, then do the patch		
		log "finding Hermes payload jmp spot location....(Hermes Setup 2/4)"	
		
		set search $my_payload_data(--jmpspot_pattern)			
		set replace ""
		set offset 0 	
		set mask 0
		# GRAB THE PATCH OFFSET VALUE ONLY
		set ::FLAG_PATCH_FILE_NOPATCH 1
		catch_die {set hermes_payload_jmp_address [::patch_elf $elf $search $offset $replace $mask]} "Unable to patch self [file tail $elf]"
		set hermes_payload_jmp_address [expr $LV2_KERNEL_BASEADDR_64 + $hermes_payload_jmp_address - $LV2_KERNEL_PROGRAM_STARTOFFSET]		
		
		## verify that the 'hermes' install spot, is PAST the 'jmp to spot', or we need to adjust
		## the jmp to be a back jmp instead of fwd jmp
		if {[expr $hermes_payload_install_spot < $hermes_payload_jmp_address]} {
			die "Unexpected error, hermes install spot needs to be adjusted!, exiting...\n"
		}				
		# calc. the offset for the 'branch'(jmp) to the hermes payload,		
		#
		# ** initial "JUMP" to the hermes payload MUST be within 24-bit offset, or we are
		#    out of range, and must move the hermes payload to a new spot **		
		set hermes_jmp_offset [format %.8X [expr {$hermes_payload_install_spot - $hermes_payload_jmp_address}]]	
		if {[expr {$hermes_payload_install_spot - $hermes_payload_jmp_address} > 16777215]} { die "Error, hermes install spot is too far from jump to, script needs fixing!!\n" }		
		
		# extract out the indiv. bytes for the 'patch'	
		# 32-bit offset is: 'b4b3b2b1'
		set temp [binary format H* $hermes_jmp_offset]		
		if {[string length $temp] == 4} {
			set byte4 [string index $temp 0]
			set byte3 [string index $temp 1]
			set byte2 [string index $temp 2]
			set byte1 [string index $temp 3]
			set offsetpatch $byte3$byte2$byte1			
		} else {
			die "failed to extract bytes for Hermes branch offset, exiting!\n"
		}				
		# ----------------------------------------------------------------- #
		# -------------- END 'HERMES PAYLOAD INSTALL LOCATION ------------- #
		# ----------------------------------------------------------------- #
				
		
		# ----------------------------------------------------------------- #
		# -------------- FIND 'HERMES PAYLOAD BRANCH ADDRESS 1' ----------- #
		# ----------------------------------------------------------------- #
		# set the 'flag' to ONLY find the patch offset initially, as we want
		# to find the address only		
		log "finding Hermes branch out address 1/2....(Hermes Setup 3/4)"
		
		set search    "\x2C\x25\x00\x00\x41\x82\x00\x50\x89\x64\x00\x00\x89\x23\x00\x00"
		append search "\x55\x60\x06\x3E\x7F\x89\x58\x00"	
		set replace   ""
		set offset 0 
		set mask 0
		# GRAB THE PATCH OFFSET VALUE ONLY
		set ::FLAG_PATCH_FILE_NOPATCH 1
		catch_die {set hermes_payload_branch_address1 [::patch_elf $elf $search $offset $replace $mask]} "Unable to patch self [file tail $elf]"
		set hermes_payload_branch_address1 [expr $LV2_KERNEL_BASEADDR_64 + $hermes_payload_branch_address1 - $LV2_KERNEL_PROGRAM_STARTOFFSET]		
		
		# verify 'branch address1' is also backwards from 'hermes install location', or
		# hermes payload branch instruct. needs to be changed
		if {[expr $hermes_payload_install_spot < $hermes_payload_branch_address1]} {
			die "Unexpected error, hermes install spot needs to be adjusted!, exiting...\n"
		}		
		# set the final value for the 'branch1' offset values		
		set hermes_payload_branch_address1 [expr $hermes_payload_branch_address1 - ($hermes_payload_install_spot + $lv2_offset_branch1)]				
		if {[expr $hermes_payload_branch_address1 < -16777215] || [expr $hermes_payload_branch_address1 > 0]} { die "hermes branch_address1 is invalid, fix script!" }
		# ----------------------------------------------------------------- #
		# -------------- END 'HERMES PAYLOAD BRANCH ADDRESS 1' ------------ #
		# ----------------------------------------------------------------- #
		
				
		# ----------------------------------------------------------------- #
		# -------------- FIND 'HERMES PAYLOAD BRANCH ADDRESS 2&3' --------- #
		# ----------------------------------------------------------------- #
		# set the 'flag' to ONLY find the patch offset initially, as we want
		# to find the address only		
		log "finding Hermes branch out address 2/2....(Hermes Setup 4/4)"
		
		set search    "\x88\x04\x00\x00\x2F\x80\x00\x00\x98\x03\x00\x00\x4D\x9E\x00\x20"
		append search "\x7C\x69\x1B\x78\x8C\x04\x00\x01\x2F\x80\x00\x00"		
		set replace   ""
		set offset 0  
		set mask 0
		# GRAB THE PATCH OFFSET VALUE ONLY
		set ::FLAG_PATCH_FILE_NOPATCH 1
		catch_die {set hermes_payload_branch_address2 [::patch_elf $elf $search $offset $replace $mask]} "Unable to patch self [file tail $elf]" 
		set hermes_payload_branch_address2 [expr $LV2_KERNEL_BASEADDR_64 + $hermes_payload_branch_address2 - $LV2_KERNEL_PROGRAM_STARTOFFSET]		
		
		# verify 'branch address2' is also backwards from 'hermes install location', or
		# hermes payload branch instruct. needs to be changed
		if {[expr $hermes_payload_install_spot < $hermes_payload_branch_address2]} {
			die "Unexpected error, hermes install spot needs to be adjusted!, exiting...\n"
		}
		# set the final value for the 'branch2' offset values		
		set hermes_payload_branch_address2 [expr $hermes_payload_branch_address2 - ($hermes_payload_install_spot + $lv2_offset_branch2)]						
		if {[expr $hermes_payload_branch_address2 < -16777215] || [expr $hermes_payload_branch_address2 > 0]} { die "hermes branch_address2 is invalid, fix script!" }
		
		# set the final value for the 'branch3' offset values
		set hermes_payload_branch_ret_address3 [expr $hermes_payload_jmp_address + $lv2_offset_ret_branch3]				
		set hermes_payload_branch_address3 [expr $hermes_payload_branch_ret_address3 - ($hermes_payload_install_spot + $lv2_offset_branch3)]		
		if {[expr $hermes_payload_branch_address3 < -16777215] || [expr $hermes_payload_branch_address3 > 0]} { die "hermes branch_address3 is invalid, fix script!" }
		# ----------------------------------------------------------------- #
		# -------------- END 'HERMES PAYLOAD BRANCH ADDRESS 2&3' ---------- #
		# ----------------------------------------------------------------- #				
			 						
		
		# populate the final data into the return array		
		set my_payload_data(--jmpspot_offset) $offsetpatch
		set my_payload_data(--payloadspot_address) $hermes_payload_install_spot
		set my_payload_data(--patch1_data) [expr $hermes_payload_install_spot + $hermes_payload_offset_string1]		
		set my_payload_data(--patch2_data) $hermes_payload_branch_address1
		set my_payload_data(--patch3_data) [expr $hermes_payload_install_spot + $hermes_payload_ptr_string2]				
		set my_payload_data(--patch4_data) $hermes_payload_branch_address2
		set my_payload_data(--patch5_data) $hermes_payload_branch_address3
		set my_payload_data(--patch6_data) [expr $hermes_payload_install_spot + $hermes_payload_offset_string2]
		set my_payload_data(--patch7_data) [expr $hermes_payload_install_spot + $hermes_payload_offset_string3]		
		if {$verbosemode eq yes} {
			log "hermes payload install spot:0x[format %llX $hermes_payload_install_spot]"
			log "hermes intercept vector at:0x[format %llX $hermes_payload_jmp_address]"
			log "hermes jmp offset:0x$hermes_jmp_offset"				
			log "hermes patch1_adddress:0x[format %llX $my_payload_data(--patch1_data)]"	
			log "hermes patch2_offset:0x[format %.6X $my_payload_data(--patch2_data)]"	
			log "hermes patch3_adddress:0x[format %llX $my_payload_data(--patch3_data)]"	
			log "hermes patch4_offset:0x[format %.6X $my_payload_data(--patch4_data)]"	
			log "hermes patch5_offset:0x[format %.6X $my_payload_data(--patch5_data)]"	
			log "hermes patch6_adddress:0x[format %llX $my_payload_data(--patch6_data)]"	
			log "hermes patch7_adddress:0x[format %llX $my_payload_data(--patch7_data)]"
		}		
	}
	### ------------------------------------------------------------------------------- ##
	### ------------------- END CONFIGURING 'HERMES' PAYLOAD -------------------------- ##
	### ------------------------------------------------------------------------------- ##
	
	# stub proc for calling the ::copy_ps3_game routine
	proc install_pkg {arg} {		
		::copy_ps3_game ${::CUSTOM_PS3_GAME}
	}		
	# this is the proc for calling the ps3mfw_base::patch_elf{} routine
	proc patch_elf {elf} {               
        catch_die {::patch_elf $elf $::patch_cos::search $::patch_cos::offset $::patch_cos::replace $::patch_cos::mask} \
        "Unable to patch self [file tail $elf]"
    }
	proc patch_devflash_self {self} {		
        log "Patching [file tail $self]"
        ::modify_self_file $self ::patch_cos::patch_devflash_file
    }
	
	# this proc is for patching dev_flash files
	proc patch_devflash_file {elf} { 
		# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #			
		# (patch seems fine, NO mask req'd)
		#
		# verified OFW ver. 4.00 - 4.55+
		# OFW 3.55: NOT FOUND
		# OFW 3.60: NOT FOUND
		# OFW 4.00: 0xFEEC (0xFDFC)
		# OFW 4.30: 0xFF08 (0xFF08
		# OFW 4.46: 0xFF08 (0xFF08)		
		# OFW 4.55: 0x100B8 (0xFFC8)		
		if {${::NEWMFW_VER} < "4.00"} {
				log "RSOD BYPASS PATCH NOT SUPPORTED BELOW 4.00!"
				die "RSOD BYPASS PATCH NOT SUPPORTED BELOW 4.00!"
		} else {
			# if "--patch-RSOD-bypass" is enabled, patch in "dev_flash\vsh\module\basic_plugins.sprx"
			if {$::patch_cos::options(--patch-RSOD-bypass)} {
				set search     "\x41\x9E\x00\x10\x2F\x9F\x00\x02\x40\x9E\x00\x20\x48\x00\x00\x10"     
				set replace    "\x48\x00"
				set offset 8
				set mask 0
				# PATCH THE ELF BINARY
				catch_die {::patch_elf $elf $search $offset $replace $mask} "Unable to patch self [file tail $elf]"
			}
		}
    }
	# --------------------------------------------------------------------------------------		
}