#import "TQNumber.h"
#import <objc/runtime.h>
#import "TQRuntime.h"
#import "TQRange.h"

#ifdef __LP64__
    #define _tqfloat double
#else
    #define _tqfloat float
#endif

static id (*numberWithDoubleImp)(id, SEL, double);
static id (*numberWithLongImp)(id, SEL, long);
static id (*allocImp)(id,SEL,NSZone*);
static id (*initImp)(id,SEL,double);
static id (*autoreleaseImp)(id,SEL);

// Hack from libobjc, aLows tail caL optimization for objc_msgSend
extern id _objc_msgSend_hack(id, SEL)      asm("_objc_msgSend");
extern id _objc_msgSend_hack2(id, SEL, id) asm("_objc_msgSend");

// Tagged pointer niceness (Uses floats by truncating the mantissa by 1 byte)
void _objc_insert_tagged_isa(unsigned char slotNumber, Class isa) asm("__objc_insert_tagged_isa");

const unsigned char kTQNumberTagSlot  = 5; // Free slot
const uintptr_t     kTQNumberTag      = (kTQNumberTagSlot << 1) | 1;

static __inline__ id _createTaggedPointer(_tqfloat value)
{
    uintptr_t ptr;
    memcpy(&ptr, &value, sizeof(_tqfloat));
    ptr &= ~0xf; // Mask out the tag bits
    ptr |= kTQNumberTag;
    return (id)ptr;
}

static __inline__ BOOL _isTaggedPointer(id ptr)
{
    return (uintptr_t)ptr & 1;
}

static __inline__ BOOL _fitsInTaggedPointer(double aValue)
{
#ifdef __LP64__
    return YES;
#else
    return (aValue > -FLT_MAX) && (aValue < FLT_MAX);
#endif
}

static __inline__ _tqfloat _TQNumberValue(TQNumber *ptr)
{
    if(_isTaggedPointer(ptr)) {
        // Zero the isa tag
        ptr = (id)(((uintptr_t)ptr) & ~kTQNumberTag);
        double val;
        memcpy(&val, &ptr, sizeof(_tqfloat));
        return val;
    }
    return ptr->_value;
}


@interface TQTaggedNumber : TQNumber
@end
@implementation TQTaggedNumber
- (id)retain { return self;}
- (oneway void)release {}
- (id)autorelease { return self; }
- (void)dealloc { if(NO) [super dealloc]; }
@end

@implementation TQNumber
@synthesize value=_value;

+ (void)load
{
    if(self != [TQNumber class]) {
        TQLog(@"Warning: Subclassing TQNumber is a bad idea!");
        // These cannot be overridden
        assert((typeof(allocImp))method_getImplementation(class_getClassMethod(self, @selector(allocWithZone:))) == allocImp);
        assert((typeof(initImp))class_getMethodImplementation(self, @selector(initWithDouble:)) == initImp);
        assert((typeof(autoreleaseImp))class_getMethodImplementation(self, @selector(autorelease)) == autoreleaseImp);
    } else {
        // Register our tagged pointer slot
        _objc_insert_tagged_isa(kTQNumberTagSlot, [TQTaggedNumber class]);

        IMP imp;
        // ==
        imp = imp_implementationWithBlock(^(TQNumber *a, id b) {
            if(!b)
                return (id)nil;
            else if(object_getClass(a) != object_getClass(b))
                return _TQNumberValue(a) == [b doubleValue] ? (id)TQValid : nil;
            return (_TQNumberValue(a) == _TQNumberValue(b))  ? (id)TQValid : nil;
        });
        class_replaceMethod(TQNumberClass, TQEqOpSel, imp, "@@:@");
        // !=
        imp = imp_implementationWithBlock(^(TQNumber *a, id b) {
            if(!b)
                return (id)nil;
            else if(object_getClass(a) != object_getClass(b))
                return _TQNumberValue(a) != [b doubleValue] ? (id)TQValid : (id)nil;
            return (_TQNumberValue(a) != _TQNumberValue(b)) ? (id)TQValid : (id)nil;
        });
        class_replaceMethod(TQNumberClass, TQNeqOpSel, imp, "@@:@");

        class_replaceMethod(TQNumberClass, TQAddOpSel,  class_getMethodImplementation(TQNumberClass, @selector(add:)),             "@@:@");
        class_replaceMethod(TQNumberClass, TQSubOpSel,  class_getMethodImplementation(TQNumberClass, @selector(subtract:)),        "@@:@");
        class_replaceMethod(TQNumberClass, TQUnaryMinusOpSel, class_getMethodImplementation(TQNumberClass, @selector(negate)),     "@@:" );
        class_replaceMethod(TQNumberClass, TQMultOpSel, class_getMethodImplementation(TQNumberClass, @selector(multiply:)),        "@@:@");
        class_replaceMethod(TQNumberClass, TQDivOpSel,  class_getMethodImplementation(TQNumberClass, @selector(divideBy:)),        "@@:@");
        class_replaceMethod(TQNumberClass, TQModOpSel,  class_getMethodImplementation(TQNumberClass, @selector(modulo:)),          "@@:@");

        class_replaceMethod(TQNumberClass, TQLTOpSel,  class_getMethodImplementation(TQNumberClass, @selector(isLesser:)),         "@@:@");
        class_replaceMethod(TQNumberClass, TQGTOpSel,  class_getMethodImplementation(TQNumberClass, @selector(isGreater:)),        "@@:@");
        class_replaceMethod(TQNumberClass, TQLTEOpSel, class_getMethodImplementation(TQNumberClass, @selector(isLesserOrEqual:)),  "@@:@");
        class_replaceMethod(TQNumberClass, TQGTEOpSel, class_getMethodImplementation(TQNumberClass, @selector(isGreaterOrEqual:)), "@@:@");
        class_replaceMethod(TQNumberClass, TQExpOpSel, class_getMethodImplementation(TQNumberClass, @selector(pow:)),              "@@:@");
    }
    numberWithDoubleImp = (id (*)(id, SEL, double))method_getImplementation(class_getClassMethod(self, @selector(numberWithDouble:)));
    numberWithLongImp   = (id (*)(id, SEL, long))method_getImplementation(class_getClassMethod(self, @selector(numberWithLong:)));

    allocImp = (typeof(allocImp))method_getImplementation(class_getClassMethod(self, @selector(allocWithZone:)));
    initImp = (typeof(initImp))class_getMethodImplementation(self, @selector(initWithDouble:));
    autoreleaseImp = (typeof(autoreleaseImp))class_getMethodImplementation(self, @selector(autorelease));
}

+ (TQNumber *)numberWithBool:(BOOL)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithBool:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithChar:(char)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithDouble:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithShort:(short)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithShort:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithInt:(int)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithInt:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithLong:(long)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithLong:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithLongLong:(long long)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithLongLong:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithFloat:(float)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithFloat:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithDouble:(double)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithDouble:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}
+ (TQNumber *)numberWithInteger:(NSInteger)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithInteger:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedChar:(unsigned char)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedChar:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedShort:(unsigned short)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedShort:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedInt:(unsigned int)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedInt:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedLong:(unsigned long)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedLong:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedLongLong:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}

+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)aValue
{
    if(_fitsInTaggedPointer(aValue))
        return _createTaggedPointer(aValue);

    TQNumber *ret = initImp(allocImp(self, @selector(allocWithZone:), nil), @selector(initWithUnsignedInteger:), aValue);
    return autoreleaseImp(ret, @selector(autorelease));
}


- (id)initWithBool:(BOOL)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithChar:(char)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithShort:(short)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithInt:(int)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithLong:(long)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithLongLong:(long long)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithFloat:(float)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithDouble:(double)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithInteger:(NSInteger)aValue
{
    _value = aValue;
    return self;
}

- (id)initWithUnsignedChar:(unsigned char)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithUnsignedShort:(unsigned short)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithUnsignedInt:(unsigned int)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithUnsignedLong:(unsigned long)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithUnsignedLongLong:(unsigned long long)aValue
{
    _value = aValue;
    return self;
}
- (id)initWithUnsignedInteger:(NSUInteger)aValue
{
    _value = aValue;
    return self;
}


- (char)charValue { return _TQNumberValue(self); }
- (short)shortValue { return _TQNumberValue(self); }
- (int)intValue { return _TQNumberValue(self); }
- (long)longValue { return _TQNumberValue(self); }
- (long long)longLongValue { return _TQNumberValue(self); }
- (float)floatValue { return _TQNumberValue(self); }
- (double)doubleValue { return _TQNumberValue(self); }
- (BOOL)boolValue { return _TQNumberValue(self); }
- (NSInteger)integerValue { return _TQNumberValue(self); }

- (unsigned char)unsignedCharValue { return _TQNumberValue(self); }
- (unsigned short)unsignedShortValue { return _TQNumberValue(self); }
- (unsigned int)unsignedIntValue { return _TQNumberValue(self); }
- (unsigned long)unsignedLongValue { return _TQNumberValue(self); }
- (unsigned long long)unsignedLongLongValue { return _TQNumberValue(self); }
- (NSUInteger)unsignedIntegerValue { return _TQNumberValue(self); }

#pragma mark - Operators

- (TQNumber *)add:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) + [b doubleValue]);
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) + _TQNumberValue(b) );
}
- (TQNumber *)subtract:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) - [b doubleValue]);
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) - _TQNumberValue(b) );
}

- (TQNumber *)negate
{
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), -_TQNumberValue(self));
}
- (TQNumber *)ceil
{
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), ceil(_TQNumberValue(self)));
}
- (TQNumber *)floor
{
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), floor(_TQNumberValue(self)));
}

- (TQNumber *)multiply:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) * [b doubleValue]);
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) * _TQNumberValue(b) );
}
- (TQNumber *)divideBy:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) / [b doubleValue]);
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), _TQNumberValue(self) / _TQNumberValue(b) );
}
- (TQNumber *)modulo:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), fmod(_TQNumberValue(self), [b doubleValue]));
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), fmod(_TQNumberValue(self), _TQNumberValue(b)));
}
- (TQNumber *)pow:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), pow(_TQNumberValue(self), [b doubleValue]));
    return numberWithDoubleImp(object_getClass(self), @selector(numberWithDouble:), pow(_TQNumberValue(self), _TQNumberValue(b) ));
}

- (TQNumber *)bitAnd:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) & [b longValue]);
    return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) & (long)_TQNumberValue(b));
}

- (TQNumber *)bitOr:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) | [b longValue]);
    return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) | (long)_TQNumberValue(b));
}

- (TQNumber *)xor:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) ^ [b longValue]);
    return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) ^ (long)_TQNumberValue(b));
}

- (TQNumber *)lshift:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) << [b longValue]);
    return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) << (long)_TQNumberValue(b));
}

- (TQNumber *)rshift:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) >> [b longValue]);
    return numberWithLongImp(object_getClass(self), @selector(numberWithLong:), (long)_TQNumberValue(self) >> (long)_TQNumberValue(b));
}


- (id)isGreater:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return _TQNumberValue(self) > [b doubleValue] ? TQValid : nil;
    return _TQNumberValue(self) > _TQNumberValue(b)  ? TQValid : nil;
}

- (id)isLesser:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return _TQNumberValue(self) < [b doubleValue] ? TQValid : nil;
    return _TQNumberValue(self) < _TQNumberValue(b)  ? TQValid : nil;
}

- (id)isGreaterOrEqual:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return _TQNumberValue(self) >= [b doubleValue] ? TQValid : nil;
    return _TQNumberValue(self) >= _TQNumberValue(b)  ? TQValid : nil;
}

- (id)isLesserOrEqual:(id)b
{
    if(object_getClass(self) != object_getClass(b))
        return _TQNumberValue(self) <= [b doubleValue] ? TQValid : nil;
    return _TQNumberValue(self) <= _TQNumberValue(b)  ? TQValid : nil;
}


- (BOOL)isEqual:(id)aObj
{
    if(object_getClass(self) == object_getClass(aObj))
        return _TQNumberValue(self) == _TQNumberValue(aObj);
    return NO;
}

- (NSComparisonResult)compare:(id)object
{
    if(object_getClass(object) != object_getClass(self))
        return NSOrderedAscending;
    TQNumber *b = object;
    double value      = _TQNumberValue(self);
    double otherValue = _TQNumberValue(b);
    if(value > otherValue)
        return NSOrderedDescending;
    else if(value < otherValue)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark -

- (TQRange *)to:(TQNumber *)b
{
    return [TQRange from:self to:b];
}

#pragma mark -

- (NSString *)description
{
    return [NSString stringWithFormat:@"%0.7g", _TQNumberValue(self)];
}

id TQDispatchBlock0(struct TQBlockLiteral *);
id TQDispatchBlock1(struct TQBlockLiteral *, id );

- (id)times:(id (^)())block
{
    if(TQBlockGetNumberOfArguments(block) == 1) {
        for(int i = 0; i < (int)_TQNumberValue(self); ++i) {
            TQDispatchBlock1((struct TQBlockLiteral *)block, [TQNumber numberWithInt:i]);
        }
    } else {
        for(int i = 0; i < (int)_TQNumberValue(self); ++i) {
            TQDispatchBlock0((struct TQBlockLiteral *)block);
        }
    }
    return nil;
}


#pragma mark - Batch allocation code
TQ_BATCH_IMPL(TQNumber)
- (void)dealloc
{
    TQ_BATCH_DEALLOC
}
@end
