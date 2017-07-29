//
//  ViewController.m
//  IOSSimulationGetWebServerRequest
//
//  Created by wujungao on 29/07/2017.
//  Copyright © 2017 wjg. All rights reserved.
//

#define MaxReadLength (512)

#pragma mark -
#import "ViewController.h"

#import "NSString+CustomString.h"

@interface ViewController ()<NSStreamDelegate>

#pragma mark -
@property (weak, nonatomic) IBOutlet UIButton *getWebServerIndexPageBtn;
@property (weak, nonatomic) IBOutlet UIButton *cancelBtn;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UITextField *webServerURLStringLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;

#pragma mark -
- (IBAction)getWebServerIndexPage:(UIButton *)sender;
- (IBAction)cancel:(UIButton *)sender;
- (IBAction)didEndOnExit:(UITextField *)sender;

#pragma mark -
@property(nonatomic,strong)NSThread *streamRunThread;
@property(nonatomic,strong)NSRunLoop *simulationRunloop;

#pragma mark -
@property(nonatomic,strong)NSInputStream *inputStream;
@property(nonatomic,strong)NSOutputStream *outputStream;

@property(nonatomic,strong)NSURL *webHostURL;

@property(nonatomic,copy)NSString *webHostURLString;

#pragma mark -
@property(nonatomic,strong)NSMutableData *receivedData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.indicator.hidden=YES;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
- (IBAction)getWebServerIndexPage:(UIButton *)sender {
    
    self.webHostURLString=self.webServerURLStringLabel.text;
    
    if([self.webHostURLString isEmptyString]){
        
        return;
    }
    
    self.webHostURLString=[NSString stringWithFormat:@"http://%@",self.webHostURLString];
    
    [self performSelector:@selector(connectToWebServerWithURLString:) onThread:self.streamRunThread withObject:self.webHostURLString waitUntilDone:NO];
    
    [self startProgressIndicatorAnimation];
    
    [self.webServerURLStringLabel resignFirstResponder];
}

- (IBAction)cancel:(UIButton *)sender {
    
    [self closeStream];
    
    [self stopProgressIndicatorAnimation];
    
    self.label.text=@"";
    
    self.receivedData=nil;
    self.streamRunThread=nil;
    
    [self.webServerURLStringLabel resignFirstResponder];
}

- (IBAction)didEndOnExit:(UITextField *)sender {
    
    [sender resignFirstResponder];
}

#pragma mark -
-(void)startProgressIndicatorAnimation{
    
    self.indicator.hidden=NO;
    [self.indicator startAnimating];
}

-(void)stopProgressIndicatorAnimation{
    
    self.indicator.hidden=YES;
    [self.indicator stopAnimating];
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
-(void)connectToWebServerWithURLString:(NSString *)urlString{
    
    self.webHostURL=[NSURL URLWithString:urlString];
    if(!self.webHostURL){
        
        self.label.text=[NSString stringWithFormat:@"Invalid %@",urlString];
        return;
    }
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)([self.webHostURL host]), 80, &readStream, &writeStream);
    
    self.inputStream=(__bridge NSInputStream *)(readStream);
    self.outputStream=(__bridge NSOutputStream *)(writeStream);
    
    self.inputStream.delegate=self;
    self.outputStream.delegate=self;
    
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    [self.inputStream open];
    [self.outputStream open];
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
                            
                            if(self.receivedData){
                            
                                [self.receivedData appendBytes:(const void *)buf length:readLength];
                            }
                        }
                    }
                    
                } while (readLength>0);
            }
            
            break;
        }
            
        case NSStreamEventEndEncountered:
        {
            if(self.inputStream==aStream){
                
                NSString *responseString=nil;//[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
                
                if(self.receivedData){
                
                    responseString=[[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
                }
                
                if(![responseString isEmptyString]){
                    
                    if(responseString.length>1024){
                        
                        responseString=[responseString substringToIndex:1025];
                    }
                    
                    self.label.text=responseString;
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
            
            self.label.text=@"NSStreamEventErrorOccurred";
            
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

#pragma mark -
-(void)runThread{
    
    NSPort *port=[[NSPort alloc] init];
    
    if(!self.simulationRunloop){
        
        self.simulationRunloop=[NSRunLoop currentRunLoop];
    }
    
    [[NSRunLoop currentRunLoop] addPort:port forMode:NSDefaultRunLoopMode];
    
    [[NSRunLoop currentRunLoop] run];
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
