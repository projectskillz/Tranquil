#import "TQNode.h"
#import "../Shared/TQDebug.h"
#import "TQNodeBlock.h"

using namespace llvm;

@implementation TQNode
@synthesize lineNumber=_lineNumber;

+ (TQNode *)node
{
    return [[self new] autorelease];
}

- (id)init
{
    if(!(self = [super init]))
        return nil;
    _lineNumber = NSNotFound;
    return self;
}

- (llvm::Value *)generateCodeInProgram:(TQProgram *)aProgram
                                 block:(TQNodeBlock *)aBlock
                                  root:(TQNodeRootBlock *)aRoot
                                 error:(NSError **)aoErr
{
    TQAssert(NO, @"Code generation has not been implemented for %@.", [self class]);
    return NULL;
}

- (llvm::Value *)store:(llvm::Value *)aValue
             inProgram:(TQProgram *)aProgram
                 block:(TQNodeBlock *)aBlock
                  root:(TQNodeRootBlock *)aRoot
                 error:(NSError **)aoErr
{
    TQAssert(NO, @"Store has not been implemented for %@.", [self class]);
    return NULL;
}

- (TQNode *)referencesNode:(TQNode *)aNode
{
    TQAssert(NO, @"Node reference check has not been implemented for %@.", [self class]);
    return nil;
}

- (void)iterateChildNodes:(TQNodeIteratorBlock)aBlock
{
    TQAssert(NO, @"Node iteration has not been implemented for %@.", [self class]);
}

- (BOOL)insertChildNode:(TQNode *)aNodeToInsert before:(TQNode *)aNodeToShift
{
    TQAssert(NO, @"%@ does not support child node insertion.", [self class]);
    return NO;
}

- (BOOL)insertChildNode:(TQNode *)aNodeToInsert after:(TQNode *)aNodeToShift
{
    TQAssert(NO, @"%@ does not support child node insertion.", [self class]);
    return NO;
}

- (BOOL)replaceChildNodesIdenticalTo:(TQNode *)aNodeToReplace with:(TQNode *)aNodeToInsert
{
    TQAssert(NO, @"%@ does not support child node replacement.", [self class]);
    return NO;
}

- (void)_attachDebugInformationToInstruction:(llvm::Instruction *)aInst inProgram:(TQProgram *)aProgram block:(TQNodeBlock *)aBlock root:(TQNodeRootBlock *)aRoot
{
    if(_lineNumber == NSNotFound)
        return;

    DebugLoc debugLoc = DebugLoc::get(self.lineNumber, 0, aBlock.scope, NULL);
    aInst->setDebugLoc(debugLoc);
    aBlock.builder->SetCurrentDebugLocation(debugLoc);
}

- (void)setLineNumber:(NSUInteger)aLineNo
{
    _lineNumber = aLineNo;
    [self iterateChildNodes:^(TQNode *aChild) {
        aChild.lineNumber = aLineNo;
    }];
}

- (NSString *)toString
{
    return [self description];
}
@end

@implementation NSArray (TQReferencesNode)
- (TQNode *)tq_referencesNode:(TQNode *)aNode
{
    TQNode *ref;
    for(TQNode *n in self) {
        ref = [n referencesNode:aNode];
        if(ref)
            return ref;
    }
    return nil;
}
@end
