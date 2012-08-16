#import "TQNodeBlock.h"
#include <llvm/Support/IRBuilder.h>

@class TQNodeWhileBlock;

@interface TQNodeIfBlock : TQNodeBlock
@property(readwrite, retain) TQNode *condition;
@property(readwrite, copy) NSMutableArray *elseBlockStatements;
// If the if block is contained within a loop, then this variable contains a reference to it
@property(readwrite, assign) TQNodeWhileBlock *containingLoop;

+ (TQNodeIfBlock *)node;
- (llvm::Value *)generateTestExpressionInProgram:(TQProgram *)aProgram
                                     withBuilder:(llvm::IRBuilder<> *)aBuilder
                                           value:(llvm::Value *)aValue;
@end

@interface TQNodeUnlessBlock : TQNodeIfBlock
+ (TQNodeUnlessBlock *)node;
@end

@interface TQNodeTernaryOperator : TQNodeIfBlock
@property(readwrite, retain) TQNode *ifExpr, *elseExpr;
+ (TQNodeTernaryOperator *)node;
+ (TQNodeTernaryOperator *)nodeWithIfExpr:(TQNode *)aIfExpr else:(TQNode *)aElseExpr;
@end
