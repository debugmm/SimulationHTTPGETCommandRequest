//
//  ViewController.m
//  SimulationGetWebServerRequest
//
//  Created by wujungao on 29/07/2017.
//  Copyright © 2017 wjg. All rights reserved.
//

#define MaxReadLength (512)

#pragma mark -
#import "ViewController.h"
#import "NSString+CustomString.h"

#pragma mark -
static NSRunLoopMode SimulationRunLoopMode = @"SimulationRunLoopMode";

#pragma mark -
@interface ViewController()<NSStreamDelegate>

@property (weak) IBOutlet NSTextField *webHostURLLabel;

@property (weak) IBOutlet NSTextField *label;
@property (weak) IBOutlet NSButton *getWebServerIndexPageBtn;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSButton *cancelBtn;

#pragma mark -
- (IBAction)getWebServerIndexPage:(NSButton *)sender;
- (IBAction)cancelGetWebServerIndexPage:(NSButton *)sender;

#pragma mark -
@property(nonatomic,strong)NSInputStream *inputStream;
@property(nonatomic,strong)NSOutputStream *outputStream;

@property(nonatomic,strong)NSURL *webHostURL;

@property(nonatomic,copy)NSString *webHostURLString;

#pragma mark -
@property(nonatomic,strong)NSMutableData *receivedData;

#pragma mark -
@property(nonatomic,strong)NSThread *streamRunThread;
@property(nonatomic,strong)NSRunLoop *simulationRunloop;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadPostNotification:) name:NSThreadWillExitNotification object:nil];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

-(void)dealloc{

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
-(void)threadPostNotification:(NSNotification *)noti{

    NSLog(@"NSThreadWillExitNotification:%@",noti);
}

#pragma mark -
- (IBAction)getWebServerIndexPage:(NSButton *)sender {
    
    self.webHostURLString=self.webHostURLLabel.stringValue;
    
    if([self.webHostURLString isEmptyString]){
        
        return;
    }
    
    self.webHostURLString=[NSString stringWithFormat:@"http://%@",self.webHostURLString];
    
    [self performSelector:@selector(connectToWebServerWithURLString:) onThread:self.streamRunThread withObject:self.webHostURLString waitUntilDone:NO];
    
    [self startProgressIndicatorAnimation];
}

- (IBAction)cancelGetWebServerIndexPage:(NSButton *)sender {
    
    [self closeStream];
    
    [self stopProgressIndicatorAnimation];
    
    self.label.stringValue=@"";

    self.receivedData=nil;
    
    [self.streamRunThread cancel];
    self.streamRunThread=nil;
}

#pragma mark -
-(void)runThread{
    
    NSPort *port=[[NSPort alloc] init];
    
    if(!self.simulationRunloop){
        
        self.simulationRunloop=[NSRunLoop currentRunLoop];
    }
    
    [[NSRunLoop currentRunLoop] addPort:port forMode:NSDefaultRunLoopMode];
    
    [[NSRunLoop currentRunLoop] run];
}

#pragma mark -
-(void)connectToWebServerWithURLString:(id)urlString{
    
    self.webHostURL=[NSURL URLWithString:(NSString *)urlString];
    if(!self.webHostURL){
        
        self.label.stringValue=[NSString stringWithFormat:@"Invalid %@",urlString];
        return;
    }
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)([self.webHostURL host]), 80, &readStream, &writeStream);
    
    self.inputStream=(__bridge NSInputStream *)(readStream);
    self.outputStream=(__bridge NSOutputStream *)(writeStream);
    
    self.inputStream.delegate=self;
    self.outputStream.delegate=self;
    
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.inputStream open];
    [self.outputStream open];
}

#pragma mark -
-(void)closeStream{

    [self closeInputStream];
    [self closeOutputStream];
}

-(void)closeInputStream{
    
    [self.inputStream close];
    
    [self.inputStream scheduleInRunLoop:self.simulationRunloop forMode:NSDefaultRunLoopMode];
}

-(void)closeOutputStream{

    [self.outputStream close];

    [self.outputStream scheduleInRunLoop:self.simulationRunloop forMode:NSDefaultRunLoopMode];
}

#pragma mark -
-(void)startProgressIndicatorAnimation{
    
    self.progressIndicator.hidden=NO;
    [self.progressIndicator startAnimation:self];
}

-(void)stopProgressIndicatorAnimation{
    
    self.progressIndicator.hidden=YES;
    [self.progressIndicator stopAnimation:self];
}

#pragma mark - StreamDelegate
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{

    switch (eventCode) {
        case NSStreamEventHasSpaceAvailable://准备写
        {
            
            if(self.outputStream==aStream){
                
                NSString *getIndexPageCommand=[NSString stringWithFormat:@"GET / HTTP/1.1\r\nHost: %@\r\n\r\n",[self.webHostURL host]];
                
                const uint8_t *getIndexPageCommandChar=(const uint8_t *)getIndexPageCommand.UTF8String;
                
                NSInteger writeLength=[self.outputStream write:getIndexPageCommandChar maxLength:strlen((const char*)getIndexPageCommandChar)];
                
                [self closeOutputStream];
            }
            
            break;
        }
          
        case NSStreamEventHasBytesAvailable://准备读
        {
            
            if(self.inputStream==aStream){
                
                NSInteger readLength=0;
                
                do {
                    
                    uint8_t buf[MaxReadLength];
                    
                    if(self.inputStream.hasBytesAvailable){
                    
                        readLength=[self.inputStream read:buf maxLength:MaxReadLength];
                        
                        if(readLength>0){
                            
                            [self.receivedData appendBytes:(const void *)buf length:readLength];
                        }
                    }
                    
                } while (readLength>0);
            }
            
            break;
        }

        case NSStreamEventEndEncountered:
        {
            if(self.inputStream==aStream){
                
                NSString *responseString=[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
                
                if(![responseString isEmptyString]){
                    
                    if(responseString.length>1024){
                    
                        responseString=[responseString substringToIndex:1025];
                    }
                    
                    self.label.stringValue=responseString;
                }
                
                [self stopProgressIndicatorAnimation];
                
                [self closeInputStream];
                
                self.receivedData=nil;
            }
            
            NSLog(@"NSStreamEventEndEncountered");

            break;
        }
            
        case NSStreamEventErrorOccurred:
        {
            
            [self closeStream];
            
            self.label.stringValue=@"NSStreamEventErrorOccurred";
            
            [self stopProgressIndicatorAnimation];
            
            NSLog(@"NSStreamEventErrorOccurred");
            break;
        }
            
        case NSStreamEventNone:
        {
        
            NSLog(@"NSStreamEventNone");
            break;
        }
            
        default:
        {
            
            break;
        }
    }
}

#pragma mark - Property
-(NSThread *)streamRunThread{

    if(!_streamRunThread){
    
        _streamRunThread=[[NSThread alloc] initWithTarget:self selector:@selector(runThread) object:nil];
        
        [_streamRunThread start];
    }
    
    return _streamRunThread;
}

-(NSMutableData *)receivedData{

    if(!_receivedData){
    
        _receivedData=[NSMutableData dataWithCapacity:1];
    }
    
    return _receivedData;
}

@end
