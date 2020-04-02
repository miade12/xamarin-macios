#!/bin/bash -e

set -o pipefail

if test -n "$V"; then set +x; fi
if test -z "$TOP"; then echo "TOP not set"; exit 1; fi
if test -z "$MACOS_DOTNET_DESTDIR"; then echo "MACOS_DOTNET_DESTDIR not set"; exit 1; fi
if test -z "$IOS_DOTNET_DESTDIR"; then echo "IOS_DOTNET_DESTDIR not set"; exit 1; fi
if test -z "$TVOS_DOTNET_DESTDIR"; then echo "TVOS_DOTNET_DESTDIR not set"; exit 1; fi
if test -z "$WATCHOS_DOTNET_DESTDIR"; then echo "WATCHOS_DOTNET_DESTDIR not set"; exit 1; fi
if test -z "$MAC_DESTDIR"; then echo "MAC_DESTDIR not set"; exit 1; fi
if test -z "$IOS_DESTDIR"; then echo "IOS_DESTDIR not set"; exit 1; fi
if test -z "$MAC_FRAMEWORK_DIR"; then echo "MAC_FRAMEWORK_DIR not set"; exit 1; fi
if test -z "$MONOTOUCH_PREFIX"; then echo "MONOTOUCH_PREFIX not set"; exit 1; fi
if test -z "$DOTNET_IOS_SDK_DESTDIR"; then echo "DOTNET_IOS_SDK_DESTDIR not set"; exit 1; fi

cp="cp -c"

copy_files ()
{
	local dotnet_destdir=$1
	local destdir=$2
	local platform=$3
	#shellcheck disable=SC2155
	local platform_lower=$(echo "$platform" | tr '[:upper:]' '[:lower:]')
	local arches_64=$4
	local arches_32=$5
	local arches="$arches_64 $arches_32"
	local assembly_infix=$6
	local framework=$7

	# the Xamarin.*OS.App.Ref nuget
	appref_destdir="$dotnet_destdir/../Xamarin.$platform.App.Ref"
	rm -Rf "$appref_destdir"
	mkdir -p "$appref_destdir/data"
	mkdir -p "$appref_destdir/ref/netcoreapp5.0"

	# the Xamarin.*OS.App nuget
	app_destdir="$dotnet_destdir/../Xamarin.$platform.App"
	rm -Rf "$app_destdir"
	mkdir -p "$app_destdir/data"
	mkdir -p "$app_destdir/lib/netcoreapp5.0"
	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$app_destdir/lib/netcoreapp5.0/"

	# the Xamarin.*OS.Sdk nuget
	rm -Rf "$dotnet_destdir"

	mkdir -p "$dotnet_destdir"
	mkdir -p "$dotnet_destdir/lib/$framework"
	mkdir -p "$dotnet_destdir/lib/netcoreapp5.0"
	mkdir -p "$dotnet_destdir/lib/netstandard2.0"
	mkdir -p "$dotnet_destdir/lib/Xamarin.$assembly_infix/v1.0/RedistList"
	mkdir -p "$dotnet_destdir/runtimes"
	for arch in $arches; do
		mkdir -p "$dotnet_destdir"/runtimes/"$platform_lower"-"$arch"/lib/netstandard1.0
	done
	mkdir -p "$dotnet_destdir/targets"
	mkdir -p "$dotnet_destdir/tools"
	mkdir -p "$dotnet_destdir/Sdk"
	mkdir -p "$dotnet_destdir/tools"
	mkdir -p "$dotnet_destdir/tools/bin"
	mkdir -p "$dotnet_destdir/ref/netcoreapp5.0"
	mkdir -p "$dotnet_destdir/data"
	for arch in $arches; do
		mkdir -p "$dotnet_destdir/tools/bin/$arch"
	done
	mkdir -p "$dotnet_destdir/tools/include"
	mkdir -p "$dotnet_destdir/tools/lib"

	$cp "$destdir/Version" "$dotnet_destdir/"
	$cp "$destdir/buildinfo" "$dotnet_destdir/tools/"

	$cp "$TOP/msbuild/dotnet/Xamarin.$platform.Sdk/Sdk/"* "$dotnet_destdir/Sdk/"
	$cp "$TOP/msbuild/dotnet/targets/"* "$dotnet_destdir/targets/"
	$cp "$TOP/msbuild/dotnet/Xamarin.$platform.Sdk/targets/"* "$dotnet_destdir/targets/"

	$cp -r "$destdir/lib/msbuild" "$dotnet_destdir/tools/"

	# linker assembly
	$cp "$TOP/tools/dotnet-linker/bin/Debug/netcoreapp3.0/dotnet-linker.dll" "$dotnet_destdir/tools/"

	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$dotnet_destdir/lib/Xamarin.$assembly_infix/v1.0/"

	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$dotnet_destdir/ref/netcoreapp5.0/"
	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$dotnet_destdir/lib/netcoreapp5.0/"
	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$dotnet_destdir/lib/netstandard2.0/"
	$cp "$TOP/msbuild/dotnet/package/$platform/FrameworkList.xml" "$dotnet_destdir/data/"


	$cp "$TOP/src/build/dotnet/$platform_lower/ref/Xamarin.$assembly_infix.dll" "$appref_destdir/ref/netcoreapp5.0/"
	$cp "$TOP/msbuild/dotnet/package/$platform/FrameworkList.xml" "$appref_destdir/data/"

	if [[ "$platform" == "iOS--disabled" ]]; then
		for arch in arm64 arm x64; do
			# FIXME: pending x86
			$cp "$DOTNET_IOS_SDK_DESTDIR/debug/netcoreapp5.0-$platform-Debug-$arch/"* "$dotnet_destdir/runtimes/$platform_lower-$arch/lib/$framework/"
		done

		for dir in "$dotnet_destdir"/runtimes/"$platform_lower"-*/lib/"$framework/"; do
			(
				cd "$dir"
				for lib in *.dylib; do
					if [[ "$lib" == "*.dylib" ]]; then
						break;
					fi
					install_name_tool -id "@executable_path/$lib" "$lib"
				done
			)
		done
	fi

	$cp "$destdir/lib/mono/Xamarin.$assembly_infix/RedistList/FrameworkList.xml" "$dotnet_destdir/lib/Xamarin.$assembly_infix/v1.0/RedistList/"

	$cp "$destdir/bin/bgen" "$dotnet_destdir/tools/bin/"
	$cp -r "$destdir/lib/bgen" "$dotnet_destdir/tools/lib/"
	if [[ "$platform" == "iOS" ]]; then
		$cp "$destdir/bin/btouch" "$dotnet_destdir/tools/bin/"
	fi
	if [[ "$platform" == "tvOS" ]]; then
		$cp "$destdir/bin/btv" "$dotnet_destdir/tools/bin/"
	fi
	if [[ "$platform" == "watchOS" ]]; then
		$cp "$destdir/bin/bwatch" "$dotnet_destdir/tools/bin/"
	fi
	if [[ "$platform" == "macOS" ]]; then
		$cp "$destdir/bin/bmac" "$dotnet_destdir/tools/bin/"
	fi

	if [[ "$platform" == "iOS--disabled--" ]]; then
		for arch in $arches; do
		case $arch in
			arm | armv7 | armv7s | armv7k | arm64_32 | arm64)
				platform_infix=iphoneos
				;;
			x86 | x64)
				platform_infix=iphonesimulator
				;;
			*)
				echo "Unknown arch: $arch"
				exit 1
				;;
			esac
			mkdir -p "$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/Xamarin.$platform.registrar.a"	"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libapp.a"						"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libextension.a"				"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libtvextension.a"				"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libwatchextension.a"			"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libxamarin-debug.a"			"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libxamarin-debug.dylib"		"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libxamarin.a"					"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
			$cp "$destdir/SDKs/MonoTouch.$platform_infix.sdk/usr/lib/libxamarin.dylib"				"$dotnet_destdir/runtimes/$platform_lower-$arch/native/"

			$cp -r "$destdir/SDKs/MonoTouch.$platform_infix.sdk/Frameworks"/Xamarin*.framework*	 "$dotnet_destdir/runtimes/$platform_lower-$arch/native/"
		done

		# FIXME: missing x86_64
		for arch in x64 arm arm64 x64; do
			unzip -oj -d "$dotnet_destdir/runtimes/$platform_lower-$arch/native/"			"$DOTNET_IOS_SDK_DESTDIR"/debug/runtime."$platform_lower".'*'-"$arch".Microsoft.NETCore.Runtime.Mono.5.0.0-dev.nupkg runtimes/"$platform_lower".'*'-"$arch"/native/'libmono.*'
			unzip -oj -d "$dotnet_destdir/runtimes/$platform_lower-$arch/lib/$framework/"	"$DOTNET_IOS_SDK_DESTDIR"/debug/runtime."$platform_lower".'*'-"$arch".Microsoft.NETCore.Runtime.Mono.5.0.0-dev.nupkg runtimes/"$platform_lower".'*'-"$arch"/lib/netstandard1.0/'*.dll'
		done

		unzip -oj -d "$dotnet_destdir/tools/bin/" "$DOTNET_IOS_SDK_DESTDIR/debug/runtime.ios.7-arm64.Microsoft.NETCore.Tool.MonoAOT.5.0.0-dev.nupkg" 'tools/mono-aot-cross'
		mv "$dotnet_destdir/tools/bin/mono-aot-cross" "$dotnet_destdir/tools/bin/arm64-darwin-mono-sgen"
		chmod +x "$dotnet_destdir/tools/bin/arm64-darwin-mono-sgen"

		unzip -oj -d "$dotnet_destdir/tools/bin/"   "$DOTNET_IOS_SDK_DESTDIR/debug/runtime.ios.7-arm.Microsoft.NETCore.Tool.MonoAOT.5.0.0-dev.nupkg"   'tools/mono-aot-cross'
		mv "$dotnet_destdir/tools/bin/mono-aot-cross" "$dotnet_destdir/tools/bin/arm-darwin-mono-sgen"
		chmod +x "$dotnet_destdir/tools/bin/arm-darwin-mono-sgen"

		$cp -r "$TOP"/runtime/xamarin "$dotnet_destdir/tools/include/"
		rm -f "$dotnet_destdir/tools/include/launch.h" # this file is macOS only
	fi

	chmod -R +r "$dotnet_destdir"
}

copy_files "$IOS_DOTNET_DESTDIR"     "$IOS_DESTDIR$MONOTOUCH_PREFIX"                   iOS     "x64 arm64" "x86 arm"             iOS     xamarinios10
copy_files "$MACOS_DOTNET_DESTDIR"   "$MAC_DESTDIR$MAC_FRAMEWORK_DIR/Versions/Current" macOS   "x64"       ""                    Mac     xamarinmac10
copy_files "$TVOS_DOTNET_DESTDIR"    "$IOS_DESTDIR$MONOTOUCH_PREFIX"                   tvOS    "x64 arm64" ""                    TVOS    xamarintvos10
copy_files "$WATCHOS_DOTNET_DESTDIR" "$IOS_DESTDIR$MONOTOUCH_PREFIX"                   watchOS ""          "x86 armv7k arm64_32" WatchOS xamarinwatchos10
