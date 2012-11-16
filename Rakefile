CC    = '/usr/local/tranquil/llvm/bin/clang'
CXX   = '/usr/local/tranquil/llvm/bin/clang++'
LD    = CC
RAGEL = '/usr/local/tranquil/ragel/bin/ragel'
LEMON = '/usr/local/tranquil/lemon/bin/lemon'

MAXARGS = 32 # The number of block dispatchers to compile

BUILD_DIR = 'Build'

LEXER_OUTPATH    = "#{BUILD_DIR}/lex.mm"
PARSER_H_OUTPATH = "#{BUILD_DIR}/parse.h"
PARSER_OUTPATH   = "#{BUILD_DIR}/parse.mm"

CXXFLAGS = {
    :release => [
        '-I`pwd`/Source',
        '-I`pwd`/Build',
        '-I/usr/include/libxml2',
        '-I/usr/local/tranquil/gmp/include',
        '`/usr/local/tranquil/llvm/bin/llvm-config --cflags`',
        #'`/usr/local/llvm.dbg/bin/llvm-config --cflags`',
        '-O3',
    ].join(' '),
    :development => [
        '-DDEBUG',
        '-I`pwd`/Source',
        '-I`pwd`/Build',
        '-I/usr/include/libxml2',
        '-I/usr/local/tranquil/gmp/include',
        '`/usr/local/tranquil/llvm/bin/llvm-config --cflags`',
        #'`/usr/local/llvm.dbg/bin/llvm-config --cflags`',
        '-O0',
        '-g',
        #'-DTQ_PROFILE',
        #'--analyze'
    ].join(' ')
}

TOOL_LDFLAGS = [
    '-L`pwd`/Build',
    '-lstdc++',
    '`/usr/local/tranquil/llvm/bin/llvm-config --ldflags --libs core jit nativecodegen armcodegen bitwriter ipo instrumentation`',
    #'`/usr/local/llvm.dbg/bin/llvm-config --ldflags --libs core jit nativecodegen bitwriter ipo instrumentation`',
    '-lclang',
    '-lobjc',
    '-ltranquil',
    '-ltranquil_codegen',
    '/usr/local/tranquil/gmp/lib/libgmp.a',
    '-rpath /usr/local/tranquil/llvm/lib',
    #'-rpath /usr/local/llvm.dbg/lib',
    '-lffi',
    '-lreadline',
    #'-lprofiler',
    '-all_load',
    '-framework Foundation',
    '-g'
].join(' ')


PATHMAP = 'build/%n.o'

STUB_OUTPATH    = 'Build/block_stubs.m'
STUB_SCRIPT     = 'Source/Tranquil/gen_stubs.rb'
STUB_H_OUTPATH  = 'Build/TQStubs.h'
STUB_H_SCRIPT   = 'Source/Tranquil/gen_stubs_header.rb'

MSGSEND_SOURCES = { :x86_64 => 'Source/Tranquil/Runtime/msgsend.x86_64.s',
                    :i386   => 'Source/Tranquil/Runtime/msgsend.i386.s',
                    :armv7  => 'Source/Tranquil/Runtime/msgsend.arm.s' }
MSGSEND_OUT     = 'Build/msgsend.o'

RUNTIME_SOURCES = FileList['Source/Tranquil/BridgeSupport/*.m*'].add('Source/Tranquil/Runtime/*.m*').add('Source/Tranquil/Shared/*.m*').add(STUB_OUTPATH)
RUNTIME_O_FILES = RUNTIME_SOURCES.pathmap(PATHMAP)
RUNTIME_O_FILES << MSGSEND_OUT

CODEGEN_SOURCES = FileList['Source/Tranquil/CodeGen/**/*.m*'] + [LEXER_OUTPATH]
CODEGEN_O_FILES = CODEGEN_SOURCES.pathmap(PATHMAP)

HEADERS         = FileList['Source/Tranquil/BridgeSupport/*.h'].add('Source/Tranquil/Dispatch/*.h').add('Source/Tranquil/Runtime/*.h').add('Source/Tranquil/Shared/*.h').add('Source/Tranquil/CodeGen/**/*.h')
HEADER_PATHMAP  = '/usr/local/tranquil/include/Tranquil/%-1d/%f'
HEADERS_OUT     = [STUB_H_OUTPATH] + HEADERS.pathmap(HEADER_PATHMAP)

LEXER_SOURCE    = "Source/Tranquil/lex.rl"
PARSER_SOURCE   = "Source/Tranquil/parse.y"

ARC_FILES = ['Source/Tranquil/Runtime/TQWeak.m']

MAIN_SOURCE  = 'Source/main.m'
MAIN_OUTPATH = 'Build/main.o'


@buildMode = :development

def compile(file, flags=CXXFLAGS[@buildMode], cc=CXX, arch="x86_64", ios=false)
    if ios == true then
        flags = flags + ' -DTQ_NO_BIGNUM' # libgmp is not well supported on iOS
        flags << ' -I/usr/local/tranquil/libffi-ios/include'
        if arch == :armv7 then
            flags << ' -miphoneos-version-min=5.0'
            flags << ' -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS6.0.sdk'
        else
            flags << ' -fobjc-abi-version=2 -fobjc-legacy-dispatch'
            flags << ' -mios-simulator-version-min=5.0'
            flags << ' -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator6.0.sdk'
        end
    else
        flags = flags + ' -mmacosx-version-min=10.7'
        flags << ' -I/usr/local/tranquil/libffi/include'
    end
    cmd = "#{cc} #{file[:in].join(' ')} -arch #{arch} #{flags} -c -o #{file[:out]}"
    unless file[:in].size == 1 and file[:in][0].end_with? '.s'
        cmd << " -fobjc-arc" if ARC_FILES.member? file[:in].first
        cmd << " -ObjC++"    if cc == CXX
        cmd << " -ObjC"      if cc == CC
    end
    sh cmd
end

HEADERS.each { |header|
    file header.pathmap(HEADER_PATHMAP) => header do |f|
        sh "mkdir -p #{f.name.pathmap('%d')}"
        sh "cp #{header} #{f.name}"
    end
}


file LEXER_OUTPATH => LEXER_SOURCE do |f|
    sh "#{RAGEL} #{LEXER_SOURCE} -o #{LEXER_OUTPATH}"
end
file PARSER_OUTPATH => PARSER_SOURCE do |f|
    sh "#{LEMON} #{PARSER_SOURCE}"
    sh "mv Source/Tranquil/parse.c #{PARSER_OUTPATH}"
    sh "mv Source/Tranquil/parse.h #{PARSER_H_OUTPATH}"
end

file STUB_OUTPATH => STUB_SCRIPT do |f|
    sh "ruby #{STUB_SCRIPT} #{MAXARGS} > #{STUB_OUTPATH}"
end

file STUB_H_OUTPATH => STUB_H_SCRIPT do |f|
    sh "ruby #{STUB_H_SCRIPT} #{MAXARGS} > Build/TQStubs.h"
    sh "mkdir -p /usr/local/tranquil/include/Tranquil/Runtime"
    sh "cp Build/TQStubs.h /usr/local/tranquil/include/Tranquil/Runtime/TQStubs.h"
end

MSGSEND_SOURCES.each do |arch, asm|
    file MSGSEND_OUT => asm do |f|
        paths = []
        MSGSEND_SOURCES.each do |arch, asm|
            outPath = MSGSEND_OUT + ".#{arch.to_s}"
            paths << outPath
            compile({:in => [asm], :out => outPath}, '', CC, arch, arch != :x86_64)
        end
        sh "lipo -create -output #{MSGSEND_OUT} #{paths.join(' ')}"
    end
end


RUNTIME_SOURCES.each { |src|
    file src.pathmap(PATHMAP) => src do |f|
        compile({:in => f.prerequisites, :out => f.name + ".x64"},  CXXFLAGS[@buildMode], CC, :x86_64)
        compile({:in => f.prerequisites, :out => f.name + ".i386"}, CXXFLAGS[@buildMode], CC, :i386,  true)
        compile({:in => f.prerequisites, :out => f.name + ".arm"},  CXXFLAGS[@buildMode], CC, :armv7, true)
        sh "lipo -create -output #{f.name} #{f.name}.x64 #{f.name}.i386 #{f.name}.arm"
    end
}
CODEGEN_SOURCES.each { |src|
    file src.pathmap(PATHMAP) => src do |f|
        compile :in => f.prerequisites, :out => f.name
    end
}


file :build_dir do
    sh "mkdir -p #{File.dirname(__FILE__)}/Build"
end

file :libtranquil => HEADERS_OUT + RUNTIME_O_FILES do |t|
    sh "libtool -static -o #{BUILD_DIR}/libtranquil.a #{RUNTIME_O_FILES}"
    sh "mkdir -p /usr/local/tranquil/lib"
    sh "cp Build/libtranquil.a /usr/local/tranquil/lib"
end

file :libtranquil_codegen => [PARSER_OUTPATH] + CODEGEN_O_FILES do |t|
    sh "ar rcs #{BUILD_DIR}/libtranquil_codegen.a #{CODEGEN_O_FILES}"
    sh "mkdir -p /usr/local/tranquil/lib"
    sh "cp Build/libtranquil_codegen.a /usr/local/tranquil/lib"
end

def _buildMain
    sh "#{CXX} #{MAIN_SOURCE} #{CXXFLAGS[@buildMode]} -ObjC++ -c -o #{MAIN_OUTPATH}"
end
file MAIN_OUTPATH => MAIN_SOURCE do |t|
end

file :tranquil => [:libtranquil, :libtranquil_codegen, MAIN_OUTPATH] do |t|
    _buildMain
    sh "#{LD} #{TOOL_LDFLAGS} #{MAIN_OUTPATH} -ltranquil_codegen -o #{BUILD_DIR}/tranquil"
end

task :setReleaseOpts do
    p "Release build"
    @buildMode = :release
end

task :run => [:default] do
    sh "#{BUILD_DIR}/tranquil"
end

task :gdb => [:default] do
    sh "gdb #{BUILD_DIR}/tranquil"
end

task :lldb => [:default] do
    sh "lldb #{BUILD_DIR}/tranquil"
end

task :clean do
    sh "rm -rf Build/*"
end

task :install => [:tranquil] do
end

def _install
    sh "mkdir -p /usr/local/tranquil/bin"
    sh "cp Build/tranquil /usr/local/tranquil/bin"
    sh "cp Tools/tqlive.tq /usr/local/tranquil/bin/tqlive"
    sh "/usr/local/tranquil/bin/tranquil Tools/tqc.tq Tools/tqc.tq -o /usr/local/tranquil/bin/tqc"
    sh "/usr/local/tranquil/bin/tqc Tools/repl.tq -lreadline /usr/local/tranquil/lib/libtranquil_codegen.a `/usr/local/tranquil/llvm/bin/llvm-config --ldflags --libs core jit nativecodegen armcodegen bitwriter ipo instrumentation` -lclang -lstdc++ -o /usr/local/tranquil/bin/tqrepl"
end

task :default => [:build_dir, :tranquil] do |t|
    _install
end
task :release => [:clean, :setReleaseOpts, :build_dir, :tranquil] do |t|
    _install
end
