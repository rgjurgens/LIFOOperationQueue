//
//  LIFOOperationQueue.m
//
//  Created by Ben Harris on 8/19/12.
//

#import "LIFOOperationQueue.h"

@interface LIFOOperationQueue ()

@property (nonatomic, strong) NSMutableArray *runningOperations;
@property dispatch_queue_t downloadQueue;

- (void)startNextOperation;
- (void)startOperation:(NSOperation *)op;


@end

@implementation LIFOOperationQueue

@synthesize maxConcurrentOperations;
@synthesize operations;
@synthesize runningOperations;

#pragma mark - Initialization

- (id)init {
    self = [super init];
    
    if (self) {
        self.operations = [NSMutableArray array];
        self.runningOperations = [NSMutableArray array];
        _downloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
    }
    
    return self;
}

- (id)initWithMaxConcurrentOperationCount:(int)maxOps {
    self = [self init];
    
    if (self) {
        self.maxConcurrentOperations = maxOps;
    }
    
    return self;
}

#pragma mark - Operation Management

//
// Adds an operation to the front of the queue
// Also starts operation on an open thread if possible
//

- (void)addOperation:(NSOperation *)op {
    if ( [self.operations containsObject:op] ) {
        [self.operations removeObject:op];
    }
    
    [self.operations insertObject:op atIndex:0];
    
    //lijst kort houden
    
//    if([self.operations count] > 15)
//    {
//        [self.operations removeLastObject];
//    }
    
    
    
    if ( self.runningOperations.count < self.maxConcurrentOperations ) {
        [self startNextOperation];
    }
}

//
// Helper method that creates an NSBlockOperation and adds to the queue
//

- (void)addOperationWithBlock:(void (^)(void))block {
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:block];
    
    [self addOperation:op];
}

//
// Attempts to cancel all operations
//

- (void)cancelAllOperations {
    self.operations = [NSMutableArray array];
    
    for (int i = 0; i < self.runningOperations.count; i++) {
        NSOperation *runningOp = [self.runningOperations objectAtIndex:i];
        [runningOp cancel];
        
        [self.runningOperations removeObject:runningOp];
        i--;
    }
}

#pragma mark - Running Operations

//
// Finds next operation and starts on first open thread
//

- (void)startNextOperation {
    if ( !self.operations.count ) {
        return;
    }
    
    if ( self.runningOperations.count < self.maxConcurrentOperations ) {
        NSOperation *nextOp = [self nextOperation];
        if (nextOp) {
            if ( !nextOp.isExecuting ) {
                [self startOperation:nextOp];
            }
            else {
                [self startNextOperation];
            }
        }
    }
}

//
// Starts operations
//

- (void)startOperation:(NSOperation *)op  {
    void (^completion)() = [op.completionBlock copy];
    
    NSOperation *blockOp = op;
    
    [op setCompletionBlock:^{
        if (completion) {
            completion();
        }
        
        [self.runningOperations removeObject:blockOp];
        [self.operations removeObject:blockOp];
        
        [self startNextOperation];
    }];
    
    [self.runningOperations addObject:op];
    
    dispatch_async(_downloadQueue, ^{
        if (!op.isExecuting)
        {
            [op start];
        }
        
    });
    
}

#pragma mark - Queue Information

//
// Returns next operation that is not already running
//

- (NSOperation *)nextOperation {
    for (int i = 0; i < self.operations.count; i++) {
        NSOperation *operation = [self.operations objectAtIndex:i];
        if ( ![self.runningOperations containsObject:operation] && !operation.isExecuting && operation.isReady ) {
            return operation;
        }
    }
    
    return nil;
}

@end
