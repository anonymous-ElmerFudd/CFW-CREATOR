#!/usr/bin/tclsh
#
# ps3mfw -- PS3 MFW creator
#
# Copyright (C) Anonymous Developers (Code Monkeys)
#
# This software is distributed under the terms of the GNU General Public
# License ("GPL") version 3, as published by the Free Software Foundation.
#
#

# PRINT USAGE
proc usage {{msg ""}} {
    global options

    ego

    if {$msg != ""} {
        puts $msg
    }
    puts "Usage: ${::argv0} \[options\] <Original> <Modified> \[task\] \[task options\]"
    puts "eg. ${::argv0} PS3UPDAT.PUP PS3UPDAT.MFW.PUP"
    puts ""
    puts "Available options are : "
    foreach option [get_sorted_options [file normalize [info script]] [array names options]] {
        puts "  $option \"$options($option)\"\n    [get_option_description [file normalize [info script]] $option]"
    }
    puts "\nAvailable tasks are : "
    foreach task [get_sorted_task_files] {
        puts "\nTask:\n--[string map {_ -} [file rootname [file tail $task]]] : [string map {\n \n\t\t\t\t} [get_task_description $task]]"
        set taskname [file rootname [file tail $task]]
        if { [llength [array names ::${taskname}::options]] } {
            puts "  Task options:"
            foreach option [get_sorted_options $task [array names ::${taskname}::options]] {
                puts "  $option \"[set ::${taskname}::options($option)]\"\n    [get_option_description $task $option]"
            }
        }
    }
    puts ""
    exit -1
}

# new routine for extracting LV0 for 3.60+ OFW (using lv0tool.exe)
# default:  (lv1ldr is NOT crypted at FW below 3.65)
#
# "lv0tool.exe" will automatically decrypt the "lv1ldr"
# if it's crypted in LV0
proc extract_lv0 {path file array} {   

	log "Extracting 3.60+ LV0 and loaders...."
	upvar $array MyLV0Hdrs
	set fullpath [file join $path $file]			
	
	# read in the SELF hdr info for LV0
	import_self_info $fullpath MyLV0Hdrs
	
	# decrypt LV0 to "LV0.elf", and
	# delete the original "lv0"	
	decrypt_self $fullpath ${fullpath}.elf
	file delete ${fullpath}
	
	# export LV0 contents.....
	append fullpath ".elf"	
	shell ${::LV0TOOL} -option export -filename ${file}.elf -filepath $path	
}

# new routine for re-packing LV0 for 3.60+ OFW (using lv0tool.exe)
# default:  crypt/decrypt "lv1ldr", unless we are under
# FW version 3.65
proc import_lv0 {path file array} {   

	log "Importing 3.60+ loaders into LV0...."
	upvar $array MySelfHdrs
	set fullpath [file join $path $file]
	set lv1ldr_crypt no
	
	# if firmware is >= 3.65, LV1LDR is crypted, otherwise it's
	# not crypted.  Also, check if we "override" this setting
	# by the flag in the "patch_coreos" task	
	if {${::NEWMFW_VER} >= "3.65"} {
		set lv1ldr_crypt yes
		if {$::FLAG_NO_LV1LDR_CRYPT != 0} {	
			set lv1ldr_crypt no
		}
	}	
	
	# execute the "lv0tool" to re-import the loaders
	shell ${::LV0TOOL} -option import -lv1crypt $lv1ldr_crypt -cleanup yes -filename ${file}.elf -filepath $path	
	
	# resign "lv0.elf" "lv0.self"
	sign_elf ${fullpath}.elf ${fullpath}.self MySelfHdrs
	
	file delete ${fullpath}.elf
	file rename -force ${fullpath}.self $fullpath		
}

proc get_log_fd {} {
    global log_fd LOG_FILE

    if {![info exists log_fd]} {
        set log_fd [open $LOG_FILE w]
        fconfigure $log_fd -buffering none
    }
    return $log_fd
}

proc log {msg {force 0}} {
    global options

    if {!$options(--silent) || $force} {
        set fd [get_log_fd]
        puts $fd $msg
        if {$force} {
            puts stderr $msg
        } else {
            puts $msg
        }
    }
}

proc debug {msg} {
    if {$::options(--debug-log)} {
        log $msg 1
    }
}

proc grep {re args} {
    set result [list]
    set files [eval glob -types f $args]
    foreach file $files {
        set fp [open $file]
        set l 0
        while {[gets $fp line] >= 0} {
            if [regexp -- $re $line] {
                lappend result [list $file $line $l]
            }
            incr l
        } 
		close $fp
    }
    set result
}

proc _get_comment_from_file {filename re} {
    set results [grep $re $filename]
    set comment ""
    foreach match $results {
        foreach {file match line} $match break
        append comment "[string trim [regsub $re $match {}]]\n"
    }
    string trim $comment
}

proc get_task_description {filename} {
    return [_get_comment_from_file $filename {^# Description:}]
}

proc get_option_description {filename option} {
    return [_get_comment_from_file $filename "^# Option ${option}:"]
}

proc get_sorted_options {filename options} {
    return [lsort -command [list sort_options $filename] $options]
}

proc sort_options {file opt1 opt2 } {
    set re1 "^# Option ${opt1}:"
    set re2 "^# Option ${opt2}:"
    set results1 [grep $re1 $file]
    set results2 [grep $re2 $file]

    if {$results1 == {} && $results2 == {}} {
        return [string compare $opt1 $opt2]
    } elseif {$results1 == {}} {
        return 1
    } elseif {$results2 == {}} {
        return -1
    } else {
        foreach {file match line1} [lindex $results1 0] break
        foreach {file match line2} [lindex $results2 0] break
        return [expr {$line1 - $line2}]
    }
}

proc get_option_type {filename option} {
    return [_get_comment_from_file $filename "^# Type ${option}:"]
}

proc task_to_file {task} {
    return [file join ${::TASKS_DIR} ${task}.tcl]
}

proc file_to_task {file} {
    return [file rootname [file tail $file]]
}

proc compare_tasks {task1 task2} {
    return [compare_task_files [task_to_file $task1] [task_to_file $task2]]
}

proc compare_task_files {file1 file2} {
    set prio1 [_get_comment_from_file $file1 {^# Priority:}]
    set prio2 [_get_comment_from_file $file2 {^# Priority:}]

    if {$prio1 == {} && $prio2 == {}} {
        return [string compare $file1 $file2]
    } elseif {$prio1 == {}} {
        return 1
    } elseif {$prio2 == {}} {
        return -1
    } else {
        return [expr {$prio1 - $prio2}]
    }
}

proc sort_tasks {tasks} {
    return [lsort -command compare_tasks $tasks]
}

proc sort_task_files {files} {
    return [lsort -command compare_task_files $files]
}

proc get_sorted_tasks { {tasks {}} } {
    set files [glob -nocomplain [file join ${::TASKS_DIR} *.tcl]]
    set tasks [list]
    foreach file $files {
        lappend tasks [file_to_task $file]
    }
    return [sort_tasks $tasks]
}

proc get_sorted_task_files { } {
    set files [glob -nocomplain [file join ${::TASKS_DIR} *.tcl]]
    return [sort_task_files $files]
}

proc get_selected_tasks { } {
    return ${::selected_tasks}
}

# failure function
proc die {message} {
    global LOG_FILE

    log "FATAL ERROR: $message" 1
    puts stderr "See ${LOG_FILE} for more info"
    puts stderr "Last lines of log : "
    puts stderr "*****************"
    catch {puts stderr "[tail $LOG_FILE]"}
    puts stderr "*****************"
    exit -2
}

proc catch_die {command message} {
    set catch {
        if {[catch {@command@} res] } {
            die "@message@ : $res"
        }
        return $res
    }
    debug "Executing command $command"
    set catch [string map [list "@command@" "$command" "@message@" "$message"] $catch]
    uplevel 1 $catch
}
# standard 'shell' to pipe output to log file
proc shell {args} {
    set fd [get_log_fd]
    debug "Executing shell $args\n"
    eval exec $args >&@ $fd
}
# enhanced 'shellex' to save output to return var
proc shellex {args} {
	set outbuffer ""    
    debug "Executing shellex $args\n"
    set outbuffer [eval exec $args]	
	return $outbuffer
}

proc hexify { str } {
    set out ""
    for {set i 0} { $i < [string length $str] } { incr i} {
        set c [string range $str $i $i]
        binary scan $c H* h
        append out "\[$h\]"
    }
    return $out
}

proc tail {filename {n 10}} {
    set fd [open $filename r]
    set lines [list]
    while {![eof $fd]} {
        lappend lines [gets $fd]
        if {[llength $lines] > $n} {
            set lines [lrange $lines end-$n end]
        }
    }
    close $fd
    return [join $lines "\n"]
}
# func to create a 'directory'
proc create_mfw_dir {args} {   
    catch_die {file mkdir $args} "Could not create dir $args"
}
# func. to copy a file
proc copy_file {args} {
    catch_die {file copy {*}$args} "Unable to copy $args"
}
# func. to copy src directory/files to dst
proc copy_dir {src dst } {   

	debug "Copying source dir:$src to target directory:$dst"
    copy_file -force $src $dst
}
# func. to sha1 check a hash
proc sha1_check {file} {
    shell ${::fciv} -add [file nativename $file] -wp -sha1 -xml db.xml
}
# func. to sha1 verify a hash
proc sha1_verify {file} {
    shell ${::fciv} [file nativename $file] -v -sha1 -xml db.xml
}
# func. to delete a file
proc delete_file {args} {
    catch_die {file delete {*}$args} "Unable to delete $args"
}
# func. to rename a file
proc rename_file {src dst} {
    catch_die {file rename {*}$src $dst} "Unable to rename and/or move $src $dst"
}

proc delete_promo { } {
    delete_file -force ${::CUSTOM_PROMO_FLAGS_TXT}
}
# func. to copy over any 'spkg_hdr.1" files
proc copy_spkg { } {
    debug "searching for spkg"
    set spkg [glob -directory ${::CUSTOM_UPDATE_DIR} *.1]
	debug "spkg found in $spkg"
	debug "copy new spkg into spkg dir"
    copy_file -force $spkg ${::CUSTOM_SPKG_DIR}
	if {[file exists [file join $spkg]]} {
	debug "removing spkg from working dir"
	delete_file -force $spkg
	}
} 
# func. to copy the 'MFW_DIR' dirs/files
proc copy_mfw_imgs { } {
    create_mfw_dir ${::CUSTOM_MFW_DIR}
    copy_file -force ${::CUSTOM_IMG_DIR} ${::CUSTOM_MFW_DIR}
}

# routine to copy standalone '*Install Package Files' app into MFW
proc copy_ps3_game {arg} {
    variable option
	set arg0 0
	set arg1 0
	set arg2 0
	set arg3 0
	set arg4 1
	
	if {[info exists ::patch_xmb::options(--add-install-pkg)]} {
		set arg0 $::patch_xmb::options(--add-install-pkg) }
	if {[info exists ::patch_xmb::options(--add-pkg-mgr)]} {
		set arg1 $::patch_xmb::options(--add-pkg-mgr) }
	if {[info exists ::patch_xmb::options(--add-hb-seg)]} {
		set arg2 $::patch_xmb::options(--add-hb-seg) }
	if {[info exists ::patch_xmb::options(--add-emu-seg)]} {
		set arg3 $::patch_xmb::options(--add-emu-seg) }
	if {[info exists ::customize_firmware::options(--customize-embedded-app)]} {
		set arg4 [file exists $::customize_firmware::options(--customize-embedded-app) == 0] }
    
    if { $arg0 || $arg1 || $arg2 || $arg3  && !$arg4 } {
        rename_file -force $arg ${::CUSTOM_EMBEDDED_APP}
    } elseif { $arg0 || $arg1 || $arg2 || $arg3  && $arg4 } {
        copy_file -force $arg ${::CUSTOM_MFW_DIR}
    } elseif { !$arg0 && !$arg1 && !$arg2 && !$arg3 && !$arg4 } {
        create_mfw_dir ${::CUSTOM_MFW_DIR}
        rename_file -force $arg ${::CUSTOM_EMBEDDED_APP}
    } elseif { !$arg0 && !$arg1 && !$arg2 && !$arg3 && $arg4 } {
        create_mfw_dir ${::CUSTOM_MFW_DIR}
        copy_file -force $arg ${::CUSTOM_MFW_DIR}
    }
	unset arg0, arg1, arg2, arg3, arg4
}

proc copy_ps3_game_standart { } {
    set ttf "SCE-PS3-RD-R-LATIN.TTF"
	debug "using font file .ttf as argument to search for"
	debug "cause we need a tar with a bit space in it"
    modify_devflash_file [file join dev_flash data font $ttf] callback_ps3_game_standart
}

proc callback_ps3_game_standart { file } {
    log "Creating custom directory in dev_flash"
	create_mfw_dir ${::CUSTOM_MFW_DIR}
	if {${::CFW} == "AC1D"} {
	    log "Installing standalone 'Custom FirmWare' app"
	    copy_file -force ${::CUSTOM_PS3_GAME2} ${::CUSTOM_MFW_DIR}
		log "Copy custom imgs into dev_flash"
	    copy_file -force ${::CUSTOM_IMG_DIR} ${::CUSTOM_MFW_DIR}
	} else {
	    log "Installing standalone '*Install Package Files' app"
	    copy_file -force ${::CUSTOM_PS3_GAME} ${::CUSTOM_MFW_DIR}
	}
}

# func. for 'extracting' the input PUP file
proc pup_extract {pup dest} {
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}
	# now extract out the PUP file
	shell ${::PKGTOOL} -debug $debugmode -action unpack -type pup -in [file nativename $pup] -out [file nativename $dest]
}

# func. for 'creating' the final PUP output
proc pup_create {dir pup build} {
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}
	# now create/pack up the PUP file
	shell ${::PKGTOOL} -debug $debugmode -action pack -type pup -in [file nativename $dir] -out $pup -buildnum $build
}

# proc for extracting pup 'build' info
proc pup_get_build {pup} {
    set fd [open $pup r]
    fconfigure $fd -translation binary
    seek $fd 16
    set build [read $fd 8]
    close $fd

    if {[binary scan $build W build_ver] != 1} {
        error "Cannot read 64 bit big endian from [hexify $build]"
    }
	
    return $build_ver
}

# proc for extracting tar files
proc extract_tar {tar dest} {
	
	debug "Extracting tar file: [file tail $tar] into: [file tail $dest]"	
	# now go untar the file
    file mkdir $dest    
    catch_die {::tar::untar $tar -dir $dest} "Could not untar file: $tar"
}

# create_tar proc, for creating custom tar files
# updated:  to set the tar hdr fields based on original file
proc create_tar {tar directory files args} {

	debug "Creating tar file:$tar, from directory:$directory\n"	
	set orgcount 0
	set buildcount 0
	set founddir 0
	set orgtar $tar
	set full_headers_list ""
	set inflags [split $args " "]
	set outflags ""	
	set verbosemode no
	# if verbose mode enabled
	if { $::options(--task-verbose) } {
		set verbosemode yes
	} 		
		
	# setup the rest of the vars
	set debug [file tail $tar]
	set myfile $tar
    if {$debug == "content" } {
        set debug [file tail [file dirname $tar]]
    }		
		
	# -------------------------------- TAR HEADERS IMPORTING ------------------------------ #
	# go read in the full 'tar' headers for the entire file, for 
	# every file in the tar	
	
	# substitute the "PS3MFW-MFW" with the "PS3MFW-OFW" dir, 
	# so we grab headers from the ORIGINAL file
	if { [regsub ($::CUSTOM_PUP_DIR) $orgtar $::ORIGINAL_PUP_DIR orgtar] } {	
		log "Importing TAR headers from file:$orgtar"		
	} else {
		log "ERROR: Failed to setup path for TAR file to import tar headers..."
		die "ERROR: Failed to setup path for TAR file to import tar headers..."
	}
	# import tar headers for all tar files
	set full_headers_list [::tar::contents_ps3mfw $orgtar]				
	set orgcount [llength $full_headers_list]	

	# -----------------------------------------
	# parse the full ORIGINAL TAR 'headers list',
	# and check if we have any DIRECTORY entries.  
	# default setup for this tar creation is to
	# create the tar with "-nodirs" specified....
	#
	# if dirs exist in original tar, then we need
	# to build the new tar WITH dirs, but ONLY the
	# dirs that exist in the original tar..
	# ***
	#
	foreach entry $full_headers_list {
		set fields [split $entry "~"]
		lassign $fields name mode uid gid mtime type
		if {$type == 5} {
			set founddir 1
			log "\n<>...there are DIRECTORIES in the ORG tar file:$orgtar, building tar WITH dirs included.....<>"			
			break
		}
	}	
	# ----------------------------------------------- #
	# parse the "inflags(args)", and if we have 
	# 'directories' in our original tar...then
	# we need to NOT set the 'nodirs' flag	
	foreach x $inflags {			
		if {[regexp "(^-nodirs).*" $x]} {
			if {$founddir == 1} { 
				continue
			} else { append outflags "$x " }
		}
	}		
	# -------------------------- DONE TAR HEADERS IMPORTING ----------------------------- #	
	# ----------------------------------------------------------------------------------- #		
	
	
    # now go and create the tar file (tar.tcl procs)
    log "Creating tar file $debug, flags:$outflags"	
	# forcibly delete the current 'tar' file
	file delete -force $tar	
    set pwd [pwd]
    cd $directory
	catch_die {::tar::create_ps3mfw $tar $files $full_headers_list buildcount {*}$outflags} "Could not create tar file $tar"
    cd $pwd	
	
	# --- VERIFY TAR FILE BUILD SUCCESSFULLY! --- #
	if {$verbosemode == yes} {
		log "Original tar count:$orgcount, Build file count:$buildcount"	
	}	
	if {$orgcount == $buildcount} {
		log "$tar file build SUCCESSFUL!\n"
	} else {
		log "Original tar count:$orgcount, Build file count:$buildcount"	
		die "Error rebuilding $tar file, terminating build"
	}	
	# ------------------------------- END TAR CREATION ---------------------------------------- #
}
# proc for 'unpackaging' dev_flash files
proc unpkg_devflash_all {updatedir outdir} {
    file mkdir $outdir
    foreach file [lsort [glob -nocomplain [file join $updatedir dev_flash_*]]] {
        unpkg_archive $file [file join $outdir [file tail $file]]
    }
}
# proc for finding the file in devflash tars
proc find_devflash_archive {dir find} {

    foreach file [glob -nocomplain [file join $dir * content]] {
        if {[catch {::tar::stat $file $find}] == 0} {
            return $file
        }
    }
    return ""
}

# ---------------------------------------------------------------------------------------------------------------------- #
# -------------------------------- PKG/SPKG functions (pkg/unpkg/spkg -------------------------------------------------- #
# proc for building the 'spkg' package
# --- no longer supported - SPKG is built as part of the 
# --- "PKG" build process!
proc spkg_archive {pkg} {
	die "This function is NO LONGER SUPPORTED!!!"
    debug "spkg-ing file: [file tail $pkg]"
    catch_die {spkg $pkg} "Could not spkg file: [file tail $pkg]"
}
proc spkg {pkg} {
	die "This function is NO LONGER SUPPORTED!!!"
    shell ${::SPKG} [file nativename $pkg]
}

# 'wrapper' function for calling "unpkg" function
proc unpkg_archive {pkg dest} {
    debug "unpkg-ing file: [file tail $pkg]"
    catch_die {unpkg $pkg $dest} "Could not unpkg file: [file tail $pkg]"
}
# function for 'unpackaging'(decrypt) a PKG file
# (outputs the 'content' file)
proc unpkg {pkg dest} {	
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}  
	# now decrypt the 'pkg' file
	shell ${::PKGTOOL} -debug $debugmode -action decrypt -type pkg -in [file nativename $pkg] -out [file nativename $dest]
}

# 'wrapper' function for calling "pkg" 
proc pkg_archive {dir pkg} {
    debug "pkg-ing file: [file tail $pkg]"
    catch_die {pkg $dir $pkg} "Could not pkg file: [file tail $pkg]"
}
# proc for building the normal 'pkg' (encrypt) package
# (outputs the ".pkg" file
proc pkg {pkg dest} {
	log "Building ORIGINAL PKG retail package"	
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	} 		
	# now go build the pkg/spkg output	
	shell ${::PKGTOOL} -debug $debugmode -action encrypt -type pkg -in [file nativename $pkg] -out [file nativename $dest]
}

# 'wrapper' function for calling "pkg_spkg"
proc pkg_spkg_archive {dir pkg} {
    debug "pkg-ing / spkg-ing file: [file tail $pkg]"
    catch_die {pkg_spkg $dir $pkg} "Could not pkg / spkg file: [file tail $pkg]"
}
# proc for building the "new" pkg with spkg headers
# (encrypt) into the pkg/spkg output files
proc pkg_spkg {pkg dest} {
	log "Building NEW PKG & SPKG retail package(s)"		
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}		
	# now go build the pkg/spkg output		
	shell ${::PKGTOOL} -debug $debugmode -action encrypt -type spkg -in [file nativename $pkg] -out [file nativename $dest]
}

# ---------------------------------------------------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------------------- #


# ---------------------------------------------------------------------------------------------------------------------- #
# -------------------------------- CORE_OS functions (cospkg/cosunpkg) ------------------------------------------------- #
# 'wrapper' function for calling "cospkg"
proc cospkg_package { dir pkg } {
    debug "cospkg-ing file: [file tail $dir]"
    catch_die { cospkg $dir $pkg } "Could not cospkg file: [file tail $pkg]"
}
# func for "packaging up" COS files
# (creates the 'content' file)
proc cospkg { dir pkg } {
	set orgfilepath $pkg
	set orgfilesize ""	
	set debugmode no	
	if { $::options(--tool-debug) } {
		set debugmode yes
	} 			
	# now go build the COS output	
	shell ${::PKGTOOL} -debug $debugmode -action pack -type cos -in [file nativename $dir] -out [file nativename $pkg]
}
# 'wrapper' function for calling "cosunpkg"
proc cosunpkg_package { pkg dest } {
    debug "cosunpkg-ing file: [file tail $pkg]"
    catch_die { cosunpkg $pkg $dest } "Could not cosunpkg file: [file tail $pkg]"
}
# function for "unpacking" CORE_COS files
# (unpacks the 'content' file
proc cosunpkg { pkg dest } {
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}    
	# now go unpack the COS pkg
	shell ${::PKGTOOL} -debug $debugmode -action unpack -type cos -in [file nativename $pkg] -out [file nativename $dest]
}
# -------------------------------------------------------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------------------------------------------------- #

proc modify_coreos_file { file callback args } {
	## core os files are now automaticallly unpacked/repacked
	## at the start/end of the MFW build script
	die "THIS ROUTINE IS NO LONGER SUPPORTED!!!"
	
    log "Modifying CORE_OS file: [file tail $file]"  	
    set pkg [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.pkg]
    set unpkgdir [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.unpkg]
    set cosunpkgdir [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE]
    
    ::unpkg_archive $pkg $unpkgdir
    ::cosunpkg_package [file join $unpkgdir content] $cosunpkgdir

    if {[file writable [file join $cosunpkgdir $file]]} {
	    set ::SELF $file
        eval $callback [file join $cosunpkgdir $file] $args
    } elseif { ![file exists [file join $cosunpkgdir $file]] } {
        die "Could not find $file in CORE_OS_PACKAGE"
    } else {
        die "File $file is not writable in CORE_OS_PACKAGE"
    }
	# rebuild the CORE_OS PKG
    ::cospkg_package $cosunpkgdir [file join $unpkgdir content]
    
	# if we are >= 3.56 FW, we need to build the new
	# "spkg" headers, otherwise use normal pkg build
	if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
		::pkg_spkg_archive $unpkgdir $pkg
        ::copy_spkg
    } else {
        ::pkg_archive $unpkgdir $pkg
    }
}

proc modify_coreos_files { files callback args } {
	## core os files are now automaticallly unpacked/repacked
	## at the start/end of the MFW build script
	die "THIS ROUTINE IS NO LONGER SUPPORTED!!!"
	
    log "Modifying CORE_OS files: [file tail $files]" 	
    set pkg [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.pkg]
    set unpkgdir [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE.unpkg]
    set cosunpkgdir [file join ${::CUSTOM_UPDATE_DIR} CORE_OS_PACKAGE]
    
    ::unpkg_archive $pkg $unpkgdir
    ::cosunpkg_package [file join $unpkgdir content] $cosunpkgdir
    
	foreach file $files {
        if {[file writable [file join $cosunpkgdir $file]]} {
		    log "Using file $file now"
			set ::SELF $file
            eval $callback [file join $cosunpkgdir $file] $args
        } elseif { ![file exists [file join $cosunpkgdir $file]] } {
            die "Could not find $file in CORE_OS_PACKAGE"
        } else {
            die "File $file is not writable in CORE_OS_PACKAGE"
        }
	}
	# rebuild the CORE_OS PKG
    ::cospkg_package $cosunpkgdir [file join $unpkgdir content]
    
    # if we are >= 3.56 FW, we need to build the new
	# "spkg" headers, otherwise use normal pkg build
	if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
		::pkg_spkg_archive $unpkgdir $pkg
        ::copy_spkg
    } else {
        ::pkg_archive $unpkgdir $pkg
    }
}

# proc for "unpackaging" the "CORE_OS" files
# 'pupdir' is directory path of PUPDIR being used
# (ie 'PS3MFW-MFW' or 'PS3MFW-OFW')
proc unpack_coreos_files { pupdir array } {
	
    log "UN-PACKAGING CORE_OS files..."  	
	upvar $array MyLV0Hdrs
	set updatedir [file join $pupdir update_files]
	set pkgfile [file join $updatedir CORE_OS_PACKAGE.pkg]
	set unpkgdir [file join $updatedir CORE_OS_PACKAGE.unpkg]
	set cosunpkgdir [file join $updatedir CORE_OS_PACKAGE]	
	
	# unpkg and cosunpkg the "COREOS.pkg"
    ::unpkg_archive $pkgfile $unpkgdir
    ::cosunpkg_package [file join $unpkgdir content] $cosunpkgdir	
	
	# if firmware is >= 3.60, we need to extract LV0 contents	
	if {${::NEWMFW_VER} >= "3.60"} {
		catch_die {extract_lv0 $cosunpkgdir "lv0" MyLV0Hdrs} "ERROR: Could not extract LV0"
	}
	
	# set the global flag that "CORE_OS" is unpacked
	set ::FLAG_COREOS_UNPACKED 1
	log "CORE_OS UNPACKED..." 	
}

# -------------------------------------------------------- #
# proc for "packaging" up the "CORE_OS" files
#
# 'ALWAYS' repack/rebuild from the 'PS3MFW-MFW' directory
# (so no need to pass a path, always always use the 
# 'CUSTOM....' paths!!
#
proc repack_coreos_files { array } {
	#::CUSTOM_PKG_DIR == $pkg
	#::CUSTOM_UNPKG_DIR == $unpkg
	#::CUSTOM_COSUNPKG_DIR == $cosunpkg
    log "RE-PACKAGING CORE_OS files..." 
	upvar $array MyLV0Hdrs

	# if firmware is >= 3.60, we need to import LV0 contents	
	if {${::NEWMFW_VER} >= "3.60"} {
		catch_die {import_lv0 $::CUSTOM_COSUNPKG_DIR "lv0" MyLV0Hdrs} "ERROR: Could not import LV0"
	}	
	
	# re-package up the files, and then
	# cleanup/delete the COSUNPKG dir
    ::cospkg_package $::CUSTOM_COSUNPKG_DIR [file join $::CUSTOM_UNPKG_DIR content]	
    # catch_die {file delete -force $::CUSTOM_COSUNPKG_DIR} "Could not delete directory:$::CUSTOM_COSUNPKG_DIR for cleanup"	
	
	# if we are >= 3.56 FW, we need to build the new
	# "spkg" headers, otherwise use normal pkg build	
	set pkg $::CUSTOM_PKG_DIR
    set unpkgdir $::CUSTOM_UNPKG_DIR
	if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
		::pkg_spkg_archive $unpkgdir $pkg
        ::copy_spkg
    } else {
        ::pkg_archive $unpkgdir $pkg
    }
	# cleanup/remove the old .unpkg dir
    catch_die {file delete -force ${unpkgdir}} "Could not delete directory:$unpkgdir for cleanup"
	
	# set the global flag that "CORE_OS" is packed
	set ::FLAG_COREOS_UNPACKED 0
	log "CORE_OS REPACKED..." 	
}
# -------------------------------------------------------- #

# proc for reading in the pup 'build' number
proc get_pup_build {} {
    debug "Getting PUP build from: [file tail ${::IN_FILE}]"
    catch_die {pup_get_build ${::IN_FILE}} "Could not get the PUP build information"
    return [pup_get_build ${::IN_FILE}]
}
# proc for 'setting' the pup 'build' number
proc set_pup_build {build} {
    debug "PUP build: $build"
    set ::PUP_BUILD $build
}
# proc for getting the pup 'version' number
proc get_pup_version {dir} {
    debug "Getting PUP version from: [file tail $dir]"
    set fd [open [file join $dir] r]
    set version [string trim [read $fd]]
    close $fd
    return $version
}
# proc for setting the pup 'version' number
proc set_pup_version {version} {
    debug "Setting PUP version in: [file tail ${::CUSTOM_VERSION_TXT}]"
    set fd [open [file join ${::CUSTOM_VERSION_TXT}] w]
    puts $fd "${version}"
    close $fd
}
# wrapper function for calling 'set_pup_version'
proc modify_pup_version_file {prefix suffix {clear 0}} {
    if {$clear} {
      set version ""
    } else {
      set version [::get_pup_version ${::ORIGINAL_VERSION_TXT}]
    }
    debug "PUP version: ${prefix}${version}${suffix}"
    set_pup_version "${prefix}${version}${suffix}"
}

proc sed_in_place {file search replace} {
    set fd [open $file r]
    set data [read $fd]
    close $fd

    set data [string map [list $search $replace] $data]

    set fd [open $file w]
    puts -nonewline $fd $data
    close $fd
}

proc unself {in out} {
    set FIN [file nativename $in]
	set FOUT [file nativename $out]

    shell ${::SCETOOL} -d $FIN $FOUT
}

# -------------------------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------- MAKESELF - USING SCETOOL ---------------------------------------------------------------- #
#
proc makeself {in out array} {   
   upvar $array MySelfHdrs   
  
   set MyKeyRev ""	
   set MyAuthID ""
   set MyVendorID ""
   set MySelfType ""
   set MyAppVersion ""
   set MyFwVersion ""
   set MyCtrlFlags ""   
   set MyCapabFlags ""
   set MyIndivSeed ""
   set MyCompressed FALSE
   set skipsection FALSE   
   set ZlibCompressLevel -1
   
	
	# set the local vars for all the SCETOOL fields, from the global vars
	# populated from the "import_sce_info{}" proc
	set MyKeyRev $MySelfHdrs(--KEYREV)
	set MyAuthID $MySelfHdrs(--AUTHID)
	set MyVendorID $MySelfHdrs(--VENDORID)
	set MySelfType $MySelfHdrs(--SELFTYPE)
	set MyFirmVersion $MySelfHdrs(--FWVERSION)
	set MyAppVersion $MySelfHdrs(--APPVERSION)	
	set MyCtrlFlags $MySelfHdrs(--CTRLFLAGS)
	set MyCapabFlags $MySelfHdrs(--CAPABFLAGS)
	set MyIndivSeed $MySelfHdrs(--INDIVSEED)
	set MyCompressed $MySelfHdrs(--COMPRESS)	
	
	
	
	# Reading the SELF version var, and setup in SCETOOL format
	# example: "0004004100000000"	
	set MyAppVersion [format "000%d00%d00000000" [lindex [split $MyAppVersion "."] 0] [lindex [split $MyAppVersion "."] 1]]	
	set ::SELF [file tail $in]	
	#debug "VERSION: $MyAppVersion"	
	
	# ----------- VERIFY 'INDIV SEED' -------------- #
	# if IndivSeed is 'none', then send empty
	# string to SCETOOL so we don't cause errors
	#
	# otherwise, verify length is EXACTLY 0x100
	# bytes (ie string length of 512 chars), or error out!
	if {$MyIndivSeed eq "NONE"} {
		set MyIndivSeed ""
	} elseif {[string length $MyIndivSeed] != 512} {
		die "Error, INDIVSEED length:[string length $MyIndivSeed] from SCE header is invalid!!, exiting...\n"
	}
	# ---------------------------------------------- #
	
	# ----- IF FOR SOME STRANGE REASON, WE ENDED UP HERE WITHOUT THE SCE HEADER INFO READ IN,
	#       THEN USE DEFAULT VALUES BELOW
	#
	# *** also, if we need to OVERRIDE any SELF HDR specific fields, we can
	#     set them manually here, to override all, or any specific fields
	# ***
	if { ($MyAuthID eq "") } {
		log "\n !!! WARNING !!!  AuthID was empty, using default SCE HDR Params!  check your setup!\n"		
		set MyAppVersion "0003004100000000"
		set MyCompressed TRUE
		set MyAuthID "1070000040000001"
		set MyVendorID "01000002"		
		set MySelfType "APP"
		set MyKeyRev "1C"
		set MyCtrlFlags     "00000000000000000000000000000000"
		append MyCtrlFlags  "00000000000000000000000000000001"
		set MyCapabFlags    "00000000000000000000000000000000"
		append MyCapabFlags "000000000000007B0000000100000000"		 		
	}
	##### ---------------------------------------------------------- ###			
	
	## make sure we have a valid authID, if it's blank, 
	## then we have an unhandled SELF type that needs to be added!!	
	if { $MyAuthID == "" } {
		#### CURRENTLY UNHANDLED TYPE - if dies here, fix the script to add  #####		
		die "Unhandled SELF TYPE:\"${::SELF}\", fix script to support it!"
	}
	# run the scetool to resign the elf file
    catch_die {shell ${::SCETOOL} -0 SELF -1 $MyCompressed -s $skipsection -2 $MyKeyRev -3 $MyAuthID -4 $MyVendorID -5 $MySelfType \
		-A $MyAppVersion -6 $MyFirmVersion -8 $MyCtrlFlags -9 $MyCapabFlags -a $MyIndivSeed -z $ZlibCompressLevel -e $in $out} "SCETOOL execution failed!"		
}
# --------------------------------------------------------------------------------------------------------------------------------------- #

# stub proc for decrypting self file
proc decrypt_self {in out} {
    debug "Decrypting self file: [file tail $in]"
    catch_die {unself $in $out} "Could not decrypt file: [file tail $in]"
}
# proc to run the scetool to dump the SELF header info
proc import_self_info {in array} {	
	
	log "Importing SELF-HDR info from file: [file tail $in]"		
	upvar $array MySelfHdrs
	set MyArraySize 0	
	
	# clear the incoming array
	foreach key [array names MySelfHdrs] {
		set MySelfHdrs($key) ""
	}
	
	# execute the "SCETOOL -w" cmd to dump the needed SCE-HDR info
    catch_die {set buffer [shellex ${::SCETOOL} -w $in]} "failed to dump SCE header for file: [file tail $in]"		
		
	# parse out the return buffer, and 
	# save off the fields into the global array
	set data [split $buffer "\n"]
	foreach line $data {
		if { [regexp -- {(^Key-Revision:)(.*)} $line match] } {		
			set MySelfHdrs(--KEYREV) [lindex [split $match ":"] 1]
			incr MyArraySize 1	
		} elseif { [regexp -- {(^Auth-ID:)(.*)} $line match] } {		
			set MySelfHdrs(--AUTHID) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^Vendor-ID:)(.*)} $line match] } {		
			set MySelfHdrs(--VENDORID) [lindex [split $match ":"] 1]	
			incr MyArraySize 1
		} elseif { [regexp -- {(^SELF-Type:)(.*)} $line match] } {		
			set MySelfHdrs(--SELFTYPE) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^AppVersion:)(.*)} $line match] } {		
			set MySelfHdrs(--APPVERSION) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^FWVersion:)(.*)} $line match] } {		
			set MySelfHdrs(--FWVERSION) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^CtrlFlags:)(.*)} $line match] } {		
			set MySelfHdrs(--CTRLFLAGS) [lindex [split $match ":"] 1]	
			incr MyArraySize 1
		} elseif { [regexp -- {(^CapabFlags:)(.*)} $line match] } {		
			set MySelfHdrs(--CAPABFLAGS) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^IndivSeed:)(.*)} $line match] } {		
			set MySelfHdrs(--INDIVSEED) [lindex [split $match ":"] 1]
			incr MyArraySize 1
		} elseif { [regexp -- {(^Compressed:)(.*)} $line match] } {		
			set MySelfHdrs(--COMPRESS) [lindex [split $match ":"] 1]	
			incr MyArraySize 1
		}
	}
	# if we successfully captured all vars, 
	# and it matches our array size, success
	if { $MyArraySize == [array size MySelfHdrs] } { 
		log "SELF-SCE HEADERS IMPORTED SUCCESSFULLY!"
	} else {
		log "!!ERROR!!:  FAILED TO IMPORT SELF-SCE HEADERS FROM FILE: [file tail $in]"
		die "!!ERROR!!:  FAILED TO IMPORT SELF-SCE HEADERS FROM FILE: [file tail $in]"
	}
	# display the imported headers if VERBOSE enabled
	if { $::options(--task-verbose) } {
		foreach key [lsort [array names MySelfHdrs]] {
			log "-->$key:$MySelfHdrs($key)"
		}	
	}		
}
# stub proc for resigning the elf
proc sign_elf {in out array} {
	upvar $array MySelfHdrs
	
    debug "Rebuilding self file: [file tail $out]"		
	# go dispatch the "makeself" routine
    catch_die {makeself $in $out MySelfHdrs} "Could not rebuild file: [file tail $out]"
}
# proc for decrypting, modifying, and re-signing a SELF file
proc modify_self_file {file callback args} {

    log "Modifying self/sprx file: [file tail $file]"
	array set MySelfHdrs {
		--KEYREV ""
		--AUTHID ""
		--VENDORID ""
		--SELFTYPE ""
		--APPVERSION ""
		--FWVERSION ""
		--CTRLFLAGS ""
		--CAPABFLAGS ""
		--INDIVSEED  ""
		--COMPRESS ""
	}
	
	# read in the SELF hdr info to save off for re-signing
	import_self_info $file MySelfHdrs	
	# decrypt the self file
    decrypt_self $file ${file}.elf
	
	# call the "callback" function to do patching/etc
    eval $callback ${file}.elf $args
	
	# now re-sign the SELF file for final output
    sign_elf ${file}.elf ${file}.self MySelfHdrs	
	#file copy -force ${file}.self ${::BUILD_DIR}    # used for debugging to copy the patched elf and new re-signed self to MFW build dir without the need to unpup the whole fw or even a single file
    file rename -force ${file}.self $file
	#file copy -force ${file}.elf ${::BUILD_DIR}     # same as above
    file delete ${file}.elf
	debug "Self successfully rebuilt"
	log "Self successfully rebuilt"
}

# wrapper function for modifying/patching a SELF file
proc patch_self {file search replace_offset replace mask} {	
    modify_self_file $file patch_elf $search $replace_offset $replace $mask
}

# proc for patching files matching the pattern with replace bytes,
# added the global "flag" check for multi-pattern replace, verus
# usual "single" pattern match
proc patch_elf {file search replace_offset replace mask} {
	set offset 0
	set mymask ""
	
	# setup the 'mask', if user specifed one!
	if {($mask != 0) && ($mask != "")} { set mymask $mask }
	
	# if 'patchtool' is enabled (default), then call the new routine,
	# otherwise, call the old TCL routines for patching
	if {$::FLAG_PATCH_USE_PATCHTOOL} {				
		set offset [patch_file_extern $file $search $replace_offset $replace $mymask]
	} else {
		# if global for 'multi' is enabled, then do multiple patches, 
		# otherwise, just do single patch
		if { $::FLAG_PATCH_FILE_MULTI != 0 } {
			set offset [patch_file_multi $file $search $replace_offset $replace $mymask]
			set ::FLAG_PATCH_FILE_MULTI 0
		} else {
			set offset [patch_file $file $search $replace_offset $replace $mymask]
		}
	}
	# return the 'offset' from the 'patch_file' function
	# (or just '0' if doing multi-patch)	
	return $offset
}

# func. for 'patching' file via external 'patchtool.exe'
proc patch_file_extern {file search replace_offset replace mask} {    
	set debugmode no	
	set verbosemode no
	set patchaction patch
	set multimode no
	set buffer ""
	set num_patches 0
	set num_matches 0	
	# if 'debug mode' enabled
	if { $::options(--tool-debug) } {
		set debugmode yes
	}	
	# if 'verbose mode' enabled
	if { $::options(--task-verbose) } {
		set verbosemode yes
	}
	
	# if 'find only' & 'multi-patching' global are enabled, then set the 
	# 'patchtool.exe' params accordingly, and reset the params
	# to default of 0
	if { $::FLAG_PATCH_FILE_NOPATCH != 0 } { set patchaction find }
	if { $::FLAG_PATCH_FILE_MULTI != 0 } { set multimode yes }
	
	# convert the data to 'hex strings'		
	set mysearch [convert_to_hexstring $search]
	set myreplace [convert_to_hexstring $replace]
	set mymask [convert_to_hexstring $mask]		
   
   # go call the 'patchtool' to do the patching or searching
	catch_die {set buffer [shellex ${::PATCHTOOL} -debug $debugmode -action $patchaction -filename [file nativename $file] \
	-search $mysearch -replace $myreplace -offset $replace_offset -mask $mymask -multi $multimode]} "patchtool.exe failed to execute!"	

	# debug/log 'patchtool.exe' buffer
	if { $verbosemode == yes } {		
		log $buffer		
	} else {
		set fd [get_log_fd]
		puts $fd $buffer	
	}
	# parse out the buffer, and attempt
	# to extract the returned 'offset'
	set data [split $buffer "\n"]
	foreach line $data {
		if {$::FLAG_PATCH_FILE_NOPATCH != 0} {
			if { [regexp {(^----FOUND MATCH AT:)(.*)} $line match] } {		
				set MyOffsetString [lindex [split $match ":"] 1]
				log "found match at:0x$MyOffsetString"
				incr num_matches
			} 
		} else {
			if { [regexp {(^----PATCHED AT:)(.*)} $line match] } {		
				set MyOffsetString [lindex [split $match ":"] 1]
				log "patched at:0x$MyOffsetString"
				incr num_patches
			}
		}
	}
	
	# print out the num matches/num patches
	if {$::FLAG_PATCH_FILE_NOPATCH != 0} {	
		if {$num_matches == 0} { die "Error: 0 matches found!" } 		
	} else {
		if {$num_patches == 0} { die "Error: 0 patches found!" } 		
	}
	# verify the returned count versus mode selected, 
	# error out if checks fail
	if {$::FLAG_PATCH_FILE_MULTI != 0} {
		if {$::FLAG_PATCH_FILE_NOPATCH == 1} {			
			debug "Found $num_matches occurrences of search pattern\n"
		} else {
			debug "Patched $num_patches occurrences of search pattern\n"
		}		
	} 
	# convert the returned 'offset' back to decimal
	#(req'd length for this hex string is '8' chars (ie 4 hex bytes)
	set MyOffset [convert_hexstring_to_decimal $MyOffsetString 8]
	
	# reset the patch flags, and return
	# the final offset	
	set ::FLAG_PATCH_FILE_NOPATCH 0
	set ::FLAG_PATCH_FILE_MULTI 0	
	return $MyOffset
}


# main function for binary patching a file (single patch occurrence)
proc patch_file {file search replace_offset replace mask} {
    
	set buffer ""	
	set returndata ""
	set mysearch ""
	set currdata ""
	set tmp ""
	set nummatches 0
    set offset -1    
	set masklen 0
	set searchlen 0	
	set filesearchlen 0
	set verbosemode no
	set do_datamask no
	# if verbose mode enabled
	if { $::options(--task-verbose) } {
		set verbosemode yes
	} 		

	# input var check, if MASK is specified, make sure the search/mask 
	# lengths are valid
	# setup initial params, log the setup
	# params if VERBOSE enabled
	set masklen [string length $mask]	
	set searchlen [string length $search]	
	if {($mask != "") && ($mask != 0)} {						
		if { ($searchlen == 0)} { die "!Error! search string length is zero!!" }
		if { ($masklen != $searchlen)} { die "!Error! Data and Mask are not equal lengths!" }
		if {[expr $masklen % 4] > 0} { die "Error! Data/Mask must be exact multiples of 4-bytes" }
		# CHECK PASSED, ENABLE DATA MASK!
		set do_datamask yes
	}		   

	# read in the entire file to the 'buffer' var
	set fd [open $file r]
    fconfigure $fd -translation binary
	set buffer [read $fd]
	set filelen [string length $buffer]	
	close $fd			
	# if 'VERBOSE' enabled, log the searching params
	if {$verbosemode == yes} {	
		if {$do_datamask == yes} {
			log "PATCH_FILE():-->filelen: 0x[format %X $filelen]"	
			log "PATCH_FILE():-->searchlen: 0x[format %X $searchlen]"		
			log "PATCH_FILE():-->masklen: 0x[format %X $masklen]"	
		}		
	}	
	
	# if the 'mask' is enabled, then setup the custom "search AND mask" pattern,
	# otherwise, just search using the original 'search' string
	if {$do_datamask == yes} {		
		# mask (AND) the 'search' data with the 'mask'
		set returndata ""		
		for {set i 0} {$i < $searchlen} {incr i 4} {						
			set databyte [string range $search $i $i+3]
			set maskbyte [string range $mask $i $i+3]			
			binary scan $databyte Iu1 dwdbyte
			binary scan $maskbyte Iu1 dwmbyte								
			set result [expr $dwdbyte & $dwmbyte]						
			append returndata [binary format Iu1 $result]						
		}
		set mysearch $returndata		
	} else { 
		set mysearch $search
	}	
	
	# ------------------------------------------------------------ #
	# ------------------- MAIN FILE BUFFER SEARCH ---------------- #
	#
	# iterate through the file buffer, searching
	# 'datalen' blocks at a time, moving forward 1 byte
	# in buffer at a time	'
	# total search length can only be total 'FILELENGTH', minus the size
	# of the 'search' pattern
	set filesearchlen [expr $filelen - $searchlen]	
	for {set i 0} {$i < $filesearchlen} {incr i} {		
					
		# if the 'mask' is enabled, AND the buffer data
		# with the 'mask' data to produce the desired buffer data
		set currdata [string range $buffer $i [expr $searchlen + $i - 1]]
		if {$do_datamask == yes} {				
			set returndata ""				
			for {set j 0} {$j < $searchlen} {incr j 4} {			
				set databyte [string range $currdata $j $j+3]
				set maskbyte [string range $mask $j $j+3]
				binary scan $databyte Iu1 dwdbyte
				binary scan $maskbyte Iu1 dwmbyte									
				set result [expr $dwdbyte & $dwmbyte]				
				append returndata [binary format Iu1 $result]
			}
			set tmp $returndata
		} else {
			set tmp $currdata
		}
		
		# if we found a match, incr the num matches		
        if {$tmp == $mysearch} {
			set offset [expr $i + $replace_offset]           
			incr nummatches			
            if {$nummatches > 1} { die "Pattern found multiple times" }	                     			 
        }
    }
	# ------------------------------------------------------------ #
	# ------------------------------------------------------------ #	
	if {$nummatches == 0} { die "Pattern not found in file!" }

	# use this flag to ONLY find the offset if we
	# set it, otherwise binary patch the file
	if {$::FLAG_PATCH_FILE_NOPATCH != 0} {	
		debug "flag set to find offset only, skipping file patching..."
		debug "match at offset: 0x[format %x $offset]"	
	} else {
		debug "patched offset: 0x[format %x $offset]"
		set fd [open $file r+]
		fconfigure $fd -translation binary	
		seek $fd $offset
		puts -nonewline $fd $replace	
		close $fd
	} 	
	# make sure we always reset the flag before leaving
	set ::FLAG_PATCH_FILE_NOPATCH 0	
	
	# return the patched "offset" in case we want
	# to use it for further patching/reference
	return $offset
}

# main function for binary patching a file (single patch occurrence)
proc patch_file_multi {file search replace_offset replace mask} {
    
	set buffer ""	
	set returndata ""
	set mysearch ""
	set currdata ""
	set tmp ""
	set nummatches 0
    set offset -1    
	set masklen 0
	set searchlen 0	
	set filesearchlen 0
	set verbosemode no
	set do_datamask no
	# if verbose mode enabled
	if { $::options(--task-verbose) } {
		set verbosemode yes
	} 		

	# input var check, if MASK is specified, make sure the search/mask 
	# lengths are valid
	# setup initial params, log the setup
	# params if VERBOSE enabled
	set masklen [string length $mask]	
	set searchlen [string length $search]	
	if {($mask != "") && ($mask != 0)} {				
		if { ($searchlen == 0)} { die "!Error! search string length is zero!!" }
		if { ($masklen != $searchlen)} { die "!Error! Data and Mask are not equal lengths!" }
		if {[expr $masklen % 4] > 0} { die "Error! Data/Mask must be exact multiples of 4-bytes" }
		# CHECK PASSED, ENABLE DATA MASK!
		set do_datamask yes
	}		   

	# read in the entire file to the 'buffer' var
	set fd [open $file r]
    fconfigure $fd -translation binary
	set buffer [read $fd]
	set filelen [string length $buffer]	
	close $fd			
	# if 'VERBOSE' enabled, log the searching params
	if {$verbosemode == yes} {	
		if {$do_datamask == yes} {
			log "PATCH_FILE_MULTI():-->filelen: 0x[format %X $filelen]"	
			log "PATCH_FILE_MULTI():-->searchlen: 0x[format %X $searchlen]"		
			log "PATCH_FILE_MULTI():-->masklen: 0x[format %X $masklen]"	
		}		
	}	
	
	# if the 'mask' is enabled, then setup the custom "search AND mask" pattern,
	# otherwise, just search using the original 'search' string
	if {$do_datamask == yes} {		
		# mask (AND) the 'search' data with the 'mask'
		set returndata ""		
		for {set i 0} {$i < $searchlen} {incr i 4} {						
			set databyte [string range $search $i $i+3]
			set maskbyte [string range $mask $i $i+3]			
			binary scan $databyte Iu1 dwdbyte
			binary scan $maskbyte Iu1 dwmbyte								
			set result [expr $dwdbyte & $dwmbyte]						
			append returndata [binary format Iu1 $result]						
		}
		set mysearch $returndata		
	} else { 
		set mysearch $search
	}	
	
	# ------------------------------------------------------------ #
	# ------------------- MAIN FILE BUFFER SEARCH ---------------- #
	#
	# iterate through the file buffer, searching
	# 'datalen' blocks at a time, moving forward 1 byte
	# in buffer at a time	'
	# total search length can only be total 'FILELENGTH', minus the size
	# of the 'search' pattern
	set filesearchlen [expr $filelen - $searchlen]	
	for {set i 0} {$i < $filesearchlen} {incr i} {		
					
		# if the 'mask' is enabled, AND the buffer data
		# with the 'mask' data to produce the desired buffer data
		set currdata [string range $buffer $i [expr $searchlen + $i - 1]]
		if {$do_datamask == yes} {				
			set returndata ""				
			for {set j 0} {$j < $searchlen} {incr j 4} {			
				set databyte [string range $currdata $j $j+3]
				set maskbyte [string range $mask $j $j+3]
				binary scan $databyte Iu1 dwdbyte
				binary scan $maskbyte Iu1 dwmbyte									
				set result [expr $dwdbyte & $dwmbyte]				
				append returndata [binary format Iu1 $result]
			}
			set tmp $returndata
		} else {
			set tmp $currdata
		}
		
		# if we found a match, incr the num matches		
        if {$tmp == $mysearch} {
			set offset [expr $i + $replace_offset]           
			incr nummatches			
			debug "patched offset: 0x[format %x $offset]"
			set fd [open $file r+]
			fconfigure $fd -translation binary	
			seek $fd $offset
			puts -nonewline $fd $replace	
			close $fd                     			 
        }
    }
	# ------------------------------------------------------------ #
	# ------------------------------------------------------------ #	
	if {$nummatches == 0} { 
		die "0 Patterns found in file!" 
	} else {
		debug "Replaced $nummatches occurrences of search pattern"
	}
	# since we are doing 'multiple' patches, just return 0
	return 0
}

# func. for modifying single dev_flash file
proc modify_devflash_file {file callback args} {

    log "Modifying dev_flash file: [file tail $file]"		
    set tar_file [find_devflash_archive ${::CUSTOM_DEVFLASH_DIR} $file]
    if {$tar_file == ""} {
        die "Could not find: [file tail $file] in devflash file"
    }

    set pkg_file [file tail [file dirname $tar_file]]
    debug "Found: [file tail $file] in $pkg_file"

    file delete -force [file join ${::CUSTOM_DEVFLASH_DIR} dev_flash]			
	# extract the original flash file
    extract_tar $tar_file ${::CUSTOM_DEVFLASH_DIR}	

    if {[file writable [file join ${::CUSTOM_DEVFLASH_DIR} $file]] } {		
        eval $callback [file join ${::CUSTOM_DEVFLASH_DIR} $file] $args
    } elseif { ![file exists [file join ${::CUSTOM_DEVFLASH_DIR} $file]] } {
        die "Could not find $file in ${::CUSTOM_DEVFLASH_DIR}"
    } else {
        die "File $file is not writable in ${::CUSTOM_DEVFLASH_DIR}"
    }	
		
	# create the tar file
	# '-nodirs' = do NOT include directories in tar file
	# '-nofinalpad'  === NO ZERO PADDING appended to file at end
    create_tar $tar_file ${::CUSTOM_DEVFLASH_DIR} dev_flash -nodirs
			    
    set pkg [file join ${::CUSTOM_UPDATE_DIR} $pkg_file]
    set unpkgdir [file join ${::CUSTOM_DEVFLASH_DIR} $pkg_file]
	
	# if we are >= 3.56 FW, we need to build the new
	# "spkg" headers, otherwise use normal pkg build
	if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
		::pkg_spkg_archive $unpkgdir $pkg
        ::copy_spkg
    } else {
        ::pkg_archive $unpkgdir $pkg
    }
}
# func. for modifying multiple dev_flash files
proc modify_devflash_files {path files callback args} {	
	
    foreach file $files {
	
        set file [file join $path $file]			
        log "Modifying dev_flash file: [file tail $file] in devflash file"
        
        set tar_file [find_devflash_archive ${::CUSTOM_DEVFLASH_DIR} $file]        
        if {$tar_file == ""} {
            debug "Skipping: [file tail $file] not found"
            continue
        }
        
        set pkg_file [file tail [file dirname $tar_file]]
        debug "Found: [file tail $file] in $pkg_file"
       
        file delete -force [file join ${::CUSTOM_DEVFLASH_DIR} dev_flash]		
        extract_tar $tar_file ${::CUSTOM_DEVFLASH_DIR}
	 
        if {[file writable [file join ${::CUSTOM_DEVFLASH_DIR} $file]] } {
		    set ::SELF $file
			log "Using file $file now"
            eval $callback [file join ${::CUSTOM_DEVFLASH_DIR} $file] $args
        } elseif { ![file exists [file join ${::CUSTOM_DEVFLASH_DIR} $file]] } {
            debug "Could not find $file in ${::CUSTOM_DEVFLASH_DIR}"
        } else {
            die "File $file is not writable in ${::CUSTOM_DEVFLASH_DIR}"
        }     
      							
		# create the tar file
		# '-nodirs' = do NOT include directories in tar file
		# '-nofinalpad'  === NO ZERO PADDING appended to file at end				
        create_tar $tar_file ${::CUSTOM_DEVFLASH_DIR} dev_flash	-nodirs
		        
        set pkg [file join ${::CUSTOM_UPDATE_DIR} $pkg_file]
        set unpkgdir [file join ${::CUSTOM_DEVFLASH_DIR} $pkg_file]		
		
		# if we are >= 3.56 FW, we need to build the new
		# "spkg" headers, otherwise use normal pkg build
		if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
			::pkg_spkg_archive $unpkgdir $pkg
			::copy_spkg
		} else {
			::pkg_archive $unpkgdir $pkg
		}
    }	
}

# .rco files handling routines
proc rco_dump {rco rco_xml rco_dir} {
    shell ${::RCOMAGE} dump [file nativename $rco] [file nativename $rco_xml] --resdir [file nativename $rco_dir]
}

proc rco_compile {rco_xml rco_new} {
    set RCOMAGE_OPTS "--pack-hdr zlib --zlib-method default --zlib-level 9"
    shell ${::RCOMAGE} compile [file nativename $rco_xml] [file nativename $rco_new] {*}$RCOMAGE_OPTS
}

proc unpack_rco_file {rco rco_xml rco_dir} {
    log "unpacking rco file: [file tail $rco]"
    catch_die {rco_dump $rco $rco_xml $rco_dir} "Could not unpack rco file: [file tail $rco]"
}

proc pack_rco_file {rco_xml rco_new} {
    log "packing rco file: [file tail $rco_new]"
    catch_die {rco_compile $rco_xml $rco_new} "Could not pack rco file: [file tail $rco_new]"
}

proc callback_modify_rco {rco_file callback callback_args} {
    set RCO_XML ${rco_file}.xml
    set RCO_DIR ${rco_file}_dir
    set RCO_NEW ${rco_file}.new

    catch_die {file mkdir $RCO_DIR} "Could not create dir $RCO_DIR"
    unpack_rco_file $rco_file $RCO_XML $RCO_DIR

    eval $callback $RCO_DIR $callback_args

    pack_rco_file $RCO_XML $RCO_NEW
    catch_die {
        file rename -force $RCO_NEW $rco_file
        file delete -force $RCO_XML
        file delete -force $RCO_DIR
    } "Could not cleanup files after modifying: [file tail $rco_file]"
}

proc modify_rco_file {rco_file callback args} {
    modify_devflash_file $rco_file callback_modify_rco $callback $args
}

# RCO callback for multiple files
proc modify_rco_files {path rco_files callback args} {
    modify_devflash_files $path $rco_files callback_modify_rco $callback $args
}

# func for modifying the "UPL.xml.pkg" file
proc modify_upl_file {callback args} {	
	
    log "Modifying UPL.xml file"	
    set file "content"
    
    set pkg [file join ${::CUSTOM_UPDATE_DIR} UPL.xml.pkg]
    set unpkgdir [file join ${::CUSTOM_UPDATE_DIR} UPL.xml.unpkg]
	set orgunpkgdir [file join ${::ORIGINAL_UPDATE_DIR} UPL.xml.unpkg]

	# unpkg the archive in the 'MFW' dir
    ::unpkg_archive $pkg $unpkgdir
	# unpkg the archive in the 'OFW' dir (for importing content info)
    ::unpkg_archive $pkg $orgunpkgdir	

	# verify 'file' is writable/etc before it's patched
    if {[file writable [file join $unpkgdir $file]] } {
        eval $callback [file join $unpkgdir $file] $args
    } elseif { ![file exists [file join $unpkgdir $file]] } {
        die "Could not find $file in $unpkgdir"
    } else {
        die "File $file is not writable in $unpkgdir"
    }
	
	# if we are >= 3.56 FW, we need to build the new
	# "spkg" headers, otherwise use normal pkg build	
	if {${::NEWMFW_VER} >= ${::OFW_2NDGEN_BASE}} {    
		::pkg_spkg_archive $unpkgdir $pkg
        ::copy_spkg
    } else {
        ::pkg_archive $unpkgdir $pkg
    }
	# cleanup/remove the old .unpkg dir
    catch_die {file delete -force ${unpkgdir}} "Could not delete directory:$unpkgdir for cleanup"
}
# func. to retrieve xml tagged data from file
proc get_header_key_upl_xml { file key message } {

    debug "Getting \"$message\" information from UPL.xml"	
	set verbosemode no
	# if verbose mode enabled
	if { $::options(--task-verbose) } {
		set verbosemode yes
	} 

	# load xml file
    set xml [::xml::LoadFile $file]
    set data [::xml::GetData $xml "UpdatePackageList:Header:$key"]
    if {$data != ""} {
		if {$verbosemode == yes} {
			log "$key:$data"
		}
        return $data
    }
    return ""
}
# func. to replace the xml tagged data in file
proc set_header_key_upl_xml { file key replace message } {

    log "Setting \"$message\" information in UPL.xml" 1	
	set finaldata ""
    set xml [::xml::LoadFile $file]

	# search the 'xml' data, and try to find the data
	# based on the 'key'
    set search [::xml::GetData $xml "UpdatePackageList:Header:$key"]
    if {$search != "" } {	
	
        set fd [open $file r]
		fconfigure $fd -translation binary 
        set xml [read $fd]
        close $fd     
		
		# iterate through the 'xml' data, and replace the line
		# with the found data
		set lines [split $xml \x0A]
		foreach line $lines {
			if { [regsub ($search) $line $replace line] } {
				log "replaced: $key: $search -> $replace"						
			}
			append finaldata $line\x0A
		}
        # write out final data
        set fd [open $file w]
		fconfigure $fd -translation binary
        puts -nonewline $fd $finaldata
        close $fd
        return $search
    }
    return ""
}

# proc to remove single 'node' from XML file
proc remove_node_from_xmb_xml { xml key message} {
    log "Removing \"$message\" from XML"

    while { [::xml::GetNodeByAttribute $xml "XMBML:View:Attributes:Table" key $key] != "" } {
        set xml [::xml::RemoveNode $xml [::xml::GetNodeIndicesByAttribute $xml "XMBML:View:Attributes:Table" key $key]]
    }
    while { [::xml::GetNodeByAttribute $xml "XMBML:View:Items:Query" key $key] != "" } {
        set xml [::xml::RemoveNode $xml [::xml::GetNodeIndicesByAttribute $xml "XMBML:View:Items:Query" key $key]]
    }

    return $xml
}
# func for changing the PUP buildnum (in PUP and in UPL.xml)
# the '<BUILD>buildnum, buildate</BUILD>' tag
proc change_build_upl_xml { filename buildnum } {

    log "Changing Buildnum in UPL.xml...."
	# retrieve the '<BUILD>.....</BUILD>' xml tag
	set data [::get_header_key_upl_xml $filename Build Build]	
	if { [regexp {(^[0-9]{5,5}),.*} $data none orgbuild] == 0} {
		die "Failed to locate build number in UPL file!\n"
	}		
	# make sure the user supplied 'buildnum' is same
	# length as original, or error out		
	if {[string length $buildnum] != [string length $orgbuild]} {
		die "Error: build number:$buildnum is invalid!!\n"
	}		
	# substitute in the new build number
	if {[regsub ($orgbuild) $data $buildnum data] == 0} {
		die "Failed updating build number in UPL file\n"
	}				
	# update the <BUILD>....</BUILD> data
	set xml [::set_header_key_upl_xml $filename Build "${data}" Build]
	if { $xml == "" } {
		die "Updating build number in UPL.xml failed...."
	} 	
	# go set the global '::BUILDNUM'
	::set_pup_build $buildnum
}

# remove single pkg from UPL.xml
proc remove_pkg_from_upl_xml { xml key message } {
    log "Removing \"$message\" package from UPL.xml" 1

    set i 0
    while { 1 } {
        set index [::xml::GetNodeIndices $xml "UpdatePackageList:Package" $i]
        if {$index == "" } break
        set node [::xml::GetNodeByIndex $xml $index]
        set data [::xml::GetData $node "Package:Type"]
        #debug "index: $index :: node: $node :: data: $data"
        if {[string equal $data $key] == 1 } {
            #debug "data: $data :: key: $key"
            set xml [::xml::RemoveNode $xml $index]
            break
        }
        incr i 1
    }
    return $xml
}
# remove pkgs from UPL.xml file
proc remove_pkgs_from_upl_xml { xml key message } {
    log "Removing \"$message\" packages from UPL.xml" 1

    set i 0
    while { 1 } {
        set index [::xml::GetNodeIndices $xml "UpdatePackageList:Package" $i]
        if {$index == "" } break
        set node [::xml::GetNodeByIndex $xml $index]
        set data [::xml::GetData $node "Package:Type"]
        #debug "index: $index :: node: $node :: data: $data"
        if {[string equal $data $key] == 1 } {
            #debug "data: $data :: key: $key"
            set xml [::xml::RemoveNode $xml $index]
            incr i -1
        }
        incr i 1
    }
    return $xml
}

# func. for 'decrypting' an SPP file
proc unspp {in out} {
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}	
	# now decrypt the SPP file
	shell ${::PKGTOOL} -debug $debugmode -action decrypt -type spp -in [file nativename $in] -out [file nativename $out]
}

# func. for 'encrypting' an SPP file
proc spp {in out} {
	set debugmode no
	if { $::options(--tool-debug) } {
		set debugmode yes
	}	
	# now encrypt the SPP file
	shell ${::PKGTOOL} -debug $debugmode -action encrypt -type spp -in [file nativename $in] -out [file nativename $out]
}

# wrapper func. for decrypting .spp file
proc decrypt_spp {in out} {
    debug "Decrypting spp file: [file tail $in]"
    catch_die {unspp $in $out} "Could not decrypt file: [file tail $in]"
}

# wrapper func. for patching decryped spp file (.pp)
# -- use the 'new' patch file routine, unless the 
#    flag is set to disabled
proc patch_pp {file search replace_offset replace} {
	if {$::FLAG_PATCH_USE_TOOL} { 
		patch_file_extern $file $search $replace_offset $replace
	} else { 
		patch_file $file $search $replace_offset $replace
	}
}

# wrapper func for encrypting .pp file (to .spp)
proc sign_pp {in out} {
    debug "Rebuilding spp file: [file tail $out]"
    catch_die {spp $in $out} "Could not rebuild file: [file tail $out]"
}

# main proc for modifying 'spp' files
proc modify_spp_file {file callback args} {

    log "Modifying spp file: [file tail $file]"	
	# decrypt the '.spp' file to a '.spp.pp' file
    decrypt_spp $file ${file}.pp
	
	# do the callback func.
    eval $callback ${file}.pp $args	
	
	# re-encrypt the '.spp.pp' file back to '.spp' file
    sign_pp ${file}.pp $file	
	# cleanup/remove the old .pp file
    catch_die {file delete -force ${file}.pp} "Could not delete $file for cleanup"
}

# proc to convert binary string of 'hex' data
# to a 'HEX' ASCII string
proc convert_to_hexstring {instring} {
	set outstring ""
	set length [string length $instring]
	
	# iterate through the string
	for {set i 0} {$i < $length} {incr i 1} {		
		set int [string index $instring $i]
		binary scan $int cu1 byte
		append outstring [format %.2X $byte]
	}
	# return the final string
	return $outstring
}

# proc to convert an incoming 'hex' ascii string
# back to decimal
proc convert_hexstring_to_decimal {instring reqlen} {
	set outstring ""
	set HexStr 0
	set dwIntFinal ""
	
	# verify instring is exactly equal to 'reqlen' (input param)
	if { [string length $instring] != $reqlen} { die "input string length:[string length $instring], does not match req'd length:$reqlen" }

	# convert back to decimal, and return
	# the final converted integer
	set HexStr [binary format H* $instring]
	binary scan $HexStr Iu1 dwIntFinal				
	return $dwIntFinal
}
#
# ------------------------------ END OF THIS SCRIPT --------------------------------------------- ##
# ----------------------------------------------------------------------------------------------- ##
