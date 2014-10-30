//
//  main.m
//  Planito
//
//  Created by Vitaliy Pronkin on 30.7.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef __PLANITO_PROT__
#import "prot2.h"
#endif

int main(int argc, char *argv[])
{
#ifdef __PLANITO_PROT__
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    if (CHECK_PROT())
    {
        [pool release];
        return NSApplicationMain(argc, (const char **)argv);
    }
    
    exit(173);
#else
    return NSApplicationMain(argc, (const char **)argv);
#endif
}
