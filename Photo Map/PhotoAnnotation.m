//
//  PhotoAnnotation.m
//  Photo Map
//
//  Created by Alex on 6/28/13.
//  Copyright (c) 2013 Alex Shevlyakov. All rights reserved.
//

#import "PhotoAnnotation.h"

@implementation PhotoAnnotation

static NSString *ASCPhotoAnnotationImagePath  = @"ASCPhotoAnnotationImagePath";
static NSString *ASCPhotoAnnotationTitle      = @"ASCPhotoAnnotationTitle";
static NSString *ASCPhotoAnnotationLatitude   = @"ASCPhotoAnnotationLatitude";
static NSString *ASCPhotoAnnotationLongitude  = @"ASCPhotoAnnotationLongitude";

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.imagePath forKey:ASCPhotoAnnotationImagePath];
    [aCoder encodeObject:self.title forKey:ASCPhotoAnnotationTitle];
    [aCoder encodeDouble:latitude forKey:ASCPhotoAnnotationLatitude];
    [aCoder encodeDouble:longitude forKey:ASCPhotoAnnotationLongitude];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.imagePath = [aDecoder decodeObjectForKey:ASCPhotoAnnotationImagePath];
        self.title = [aDecoder decodeObjectForKey:ASCPhotoAnnotationTitle];
        
        double aLatitude  = [aDecoder decodeDoubleForKey:ASCPhotoAnnotationLatitude];
        double aLongitude = [aDecoder decodeDoubleForKey:ASCPhotoAnnotationLongitude];
        CLLocationCoordinate2D coord;
        coord.latitude = aLatitude;
        coord.longitude = aLongitude;
        
        self.coordinate = coord;
    }
    return self;
}

- (id)initWithImagePath:(NSString *)imagePath title:(NSString *)title coordinate:(CLLocationCoordinate2D)coord {
    self = [super init];
    if (self) {
        self.imagePath = imagePath;
        self.title = title;
        self.coordinate = coord;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    _coordinate = coordinate;
    latitude = coordinate.latitude;
    longitude = coordinate.longitude;
}

@end
