#!/usr/bin/tclsh
#
# ps3mfw -- PS3 MFW creator
#
# Copyright (C) Anonymous Developers (Code Monkeys)
#
# This software is distributed under the terms of the GNU General Public
# License ("GPL") version 3, as published by the Free Software Foundation.
#

# Priority: 0006
# Description: PATCH: LV2 - Miscellaneous


# Option --patch-lv2-antiode-check-1: [4.xx]  LV2: --> Patch LV2 to remove anti-ODE check #1 - OFW 4.60+ (0x80010017)
# Option --patch-lv2-antiode-check-2: [4.xx]  LV2: --> Patch LV2 to remove anti-ODE check #2 - OFW 4.60+ (0x8001002B)

# Type --patch-lv2-antiode-check-1: boolean
# Type --patch-lv2-antiode-check-2: boolean


namespace eval ::patch_lv2 {

    array set ::patch_lv2::options {
		--patch-lv2-antiode-check-1 true
		--patch-lv2-antiode-check-2 true
    }
		
    proc main { } {
	
        # call the function to do any LV2_KERNEL selected patches				
		set self "lv2_kernel.self"
		set path $::CUSTOM_COSUNPKG_DIR
		set file [file join $path $self]		
		::modify_self_file $file ::patch_lv2::Do_LV2_Patches	    
    }   
	
	##################			 proc for applying any  "MISCELLANEOUS"  LV2_KERNEL patches    	##############################################################
	#
	#
	# ----- Any 'misc' LV2 patches will be handled here, ie NON-CRITICAL LV2 patches ------
	#
	proc Do_LV2_Patches {elf} {
	
		# apply any MISC lv2 patches here....		
		log "Applying LV2 Miscellaneous patches...."								
		
		# ** ANTI-ODE PATCH #1 IN OFW VERSIONS 4.60+ **
        if {$::patch_lv2::options(--patch-lv2-antiode-check-1)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			#
			# verified OFW ver. 4.60 - 4.65+
			# OFW 4.60 == 0x68DAC (0x80058DAC)			
			# OFW 4.65 == 0x68DB0 (0x80058DB0)		
			if {${::NEWMFW_VER} >= "4.60"} {
			
				log "Patching Lv2 to disable Anti-ODE Check #1"									
				set search  "\x2F\x83\x00\x00\x7C\x7F\x1B\x78\x41\x9E\x00\x38\xE8\x61\x00\x98\x2F\xA3\x00\x00\x41\x9E\x00\x0C\x38\x80\x00\x33"
				set mask	"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\xFF\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\xFF\xFF\xFF\xFF" ;# <-- mask off the bits/bytes			
				set replace "\x60\x00\x00\x00"			    ;# ^^ patch starts here 
				set offset 8					
				# PATCH THE ELF BINARY
				catch_die {::patch_elf $elf $search $offset $replace $mask} "Unable to patch self [file tail $elf]"     
				
			} else {	
				log "SKIPPING ANTI-ODE-CHECK PATCH #1, this check does not exist in OFW below 4.60...."				
			}
			
		# ** ANTI-ODE PATCH #2 IN OFW VERSIONS 4.60+ **
		if {$::patch_lv2::options(--patch-lv2-antiode-check-2)} {
			# <><> --- OPTIMIZED FOR 'PATCHTOOL' --- <><> #
			#
			# verified OFW ver. 4.60 - 4.65+
			# OFW 4.60 == 0x65C58 (0x80055C58)	
			# OFW 4.65 == 0x65C58 (0x80055C58)		
			if {${::NEWMFW_VER} >= "4.60"} {
			
				log "Patching Lv2 to disable Anti-ODE Check #2"						
				set search    "\xF8\x21\xFE\x91\x7C\x08\x02\xA6\xFB\xC1\x01\x60\xFB\xE1\x01\x68\xFB\x61\x01\x48\xFB\x81\x01\x50\xFB\xA1\x01\x58"
				append search "\xF8\x01\x01\x80\x7C\x9F\x23\x78\x7C\xBE\x2B\x78\x48\x1D\xA6\x69\x2F\x83\x00\x01"
				set mask	  "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"	
				append mask	  "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\xFF\xFF\xFF\xFF"
				set replace   "\x38\x60\x00\x00\x4E\x80\x00\x20"			      ;# ^^ patch starts here 
				set offset 0					
				# PATCH THE ELF BINARY
				catch_die {::patch_elf $elf $search $offset $replace $mask} "Unable to patch self [file tail $elf]"     
				
			} else {	
				log "SKIPPING ANTI-ODE-CHECK PATCH #2, this check does not exist in OFW below 4.60...."				
			}
        }		
		log "Done LV2 Miscellaneous patches...."						
    }
	##
	################################################################################################################################################
  }
}
	