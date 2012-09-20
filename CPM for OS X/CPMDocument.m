//
//  CPMDocument.m
//  CPM for OS X
//
//  Created by Thomas Harte on 12/09/2012.
//  Copyright (c) 2012 Thomas Harte. All rights reserved.
//

#import "CPMDocument.h"
#import "BDOS.h"
#import "TerminalView.h"
#import "FuseTestRunner.h"

@class CPMTerminalView;

@interface CPMDocument ()

@property (nonatomic, assign) IBOutlet CPMTerminalView *terminalView;

@end

@implementation CPMDocument
{
	NSURL *_sourceURL;
	CPMBDOS *_bdos;
	NSTimer *_executionTimer;
	dispatch_queue_t serialDispatchQueue;

	NSUInteger _blockedCount;
	BOOL _disallowFastExecution;
}

- (void)close
{
	[_bdos release], _bdos = nil;
	[_executionTimer invalidate], _executionTimer = nil;
	[_sourceURL release], _sourceURL = nil;
	if(serialDispatchQueue)
	{
		dispatch_release(serialDispatchQueue), serialDispatchQueue = NULL;
	}
}

- (NSString *)windowNibName
{
	// Override returning the nib file name of the document
	// If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
	return @"CPMDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	[super windowControllerDidLoadNib:aController];
	// Add any code here that needs to be executed once the windowController has loaded the document's window.

	_bdos = [[CPMBDOS BDOSWithContentsOfURL:_sourceURL terminalView:self.terminalView] retain];

	// get base path...
	_bdos.basePath = [[_sourceURL path] stringByDeletingLastPathComponent];

	// call our execution timer 50 times a second, as a nod towards PAL
	serialDispatchQueue = dispatch_queue_create("CPM dispatch queue", DISPATCH_QUEUE_SERIAL);
	_executionTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(doMoreProcessing:) userInfo:nil repeats:YES];

	[aController.window setContentAspectRatio:[self.terminalView idealSize]];
//	[aController.window setTitle:[[[_sourceURL path] stringByDeletingPathExtension] lastPathComponent]];

//	CPMFuseTestRunner *testRunner = [[CPMFuseTestRunner alloc] init];
//	[testRunner go];
//	[testRunner release];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	// Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
	// You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
//	NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
//	@throw exception;
	return [NSData data];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	_sourceURL = [url retain];
	return YES;
}

- (void)doMoreProcessing:(NSTimer *)timer
{
	/*

		Logic is:

			- ordinarily (ie, when fast execution isn't disallowed) allow up to 90%
			utilisation; but
			- if that full amount is used for a second then cut avaiable CPU time
			down to just 50%; and
			- restore full speed execution only if the alotted 50% isn't used for
			at least a second.

		So the motivation is not to penalise apps that occasionally do a lot of
		processing but mostly block waiting for input while preventing apps that
		run a busy loop from wasting your modern multi-tasking computer's
		processing time.

	*/
	dispatch_async(serialDispatchQueue,
	^{
		if(_disallowFastExecution)
		{
			[_bdos runForTimeInterval:0.01];
			if(_bdos.didBlock)
			{
				_blockedCount++;
				if(_blockedCount == 100) _disallowFastExecution = NO;
			}
			else
				_blockedCount = 0;
		}
		else
		{
			[_bdos runForTimeInterval:0.018];
			if(!_bdos.didBlock)
			{
				_blockedCount++;
				if(_blockedCount == 56) _disallowFastExecution = YES;
			}
			else
				_blockedCount = 0;
		}
	});
}


@end