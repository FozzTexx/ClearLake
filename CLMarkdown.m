/* Copyright 2016 by
 *   Chris Osborn <fozztexx@fozztexx.com>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2.1, or (at your option) any later
 * version.
 *
 * ClearLake is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with ClearLake; see the file COPYING. If not see
 * <http://www.gnu.org/licenses/>.
 */

#import "CLMarkdown.h"
#import <ClearLake/CLString.h>
#import <ClearLake/CLDictionary.h>
#import <ClearLake/CLArray.h>
#import <ClearLake/CLNull.h>

#include <hoedown/buffer.h>
#include <hoedown/document.h>
#include <hoedown/html.h>
#include <string.h>

#define INPUT_UNIT  1024
#define OUTPUT_UNIT 64

/* There's an option to set a callback for adding attributes to the A
   tag, but they forgot that a callback is pointless if you can't set
   it. */
struct hoedown_hack {
  hoedown_renderer md;
  hoedown_renderer_data data;
};

void CLLinkAttributesCallback(hoedown_buffer *ob, const hoedown_buffer *url,
			      const hoedown_renderer_data *data)
{
  hoedown_html_renderer_state *state;
  CLDictionary *linkAttributes;
  int i, j;
  CLArray *keys;
  CLString *aKey;
  id aValue;


  state = data->opaque;
  linkAttributes = [((CLMarkdown *) state->opaque) linkAttributes];

  keys = [linkAttributes allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aKey = [keys objectAtIndex:i];
    aValue = [linkAttributes objectForKey:aKey];

    if (aValue) {
      hoedown_buffer_puts(ob, [[CLString stringWithFormat:@" %@", aKey] UTF8String]);
      if (aValue != CLNullObject)
	hoedown_buffer_puts(ob, [[CLString stringWithFormat:@"=\"%@\"",
					   [[aValue description] entityEncodedString]]
				  UTF8String]);
    }
  }
  
  return;
}

@implementation CLMarkdown

+(id) markdownFromString:(CLString *) aString
{
  return [[[self alloc] initFromString:aString linkAttributes:nil] autorelease];
}

+(id) markdownFromString:(CLString *) aString linkAttributes:(CLDictionary *) laDict
{
  return [[[self alloc] initFromString:aString linkAttributes:laDict] autorelease];
}

-(id) init
{
  return [self initFromString:nil linkAttributes:nil];
}

-(id) initFromString:(CLString *) aString linkAttributes:(CLDictionary *) laDict
{
  [super init];
  mdstr = [aString copy];
  linkAttributes = [laDict copy];
  return self;
}

-(void) dealloc
{
  [mdstr release];
  [linkAttributes release];
  [super dealloc];
  return;
}
  
-(CLString *) html
{
  hoedown_buffer B;
  hoedown_document *D;
  hoedown_renderer *R;
  CLString *aString;
  const char *str;
  hoedown_html_renderer_state *state;
  struct hoedown_hack *hack;
  
  
  hoedown_buffer_init(&B, 1024, realloc, free, free);
  R = hoedown_html_renderer_new(HOEDOWN_HTML_ESCAPE, 0);
  /* HOEDOWN_AUTOLINK_NORMAL */
  D = hoedown_document_new(R, HOEDOWN_EXT_STRIKETHROUGH
			   | HOEDOWN_EXT_UNDERLINE
			   | HOEDOWN_EXT_SUPERSCRIPT
			   | HOEDOWN_EXT_AUTOLINK, 16);
  hack = (struct hoedown_hack *) D;
  state = hack->data.opaque;
  state->opaque = self;
  state->link_attributes = CLLinkAttributesCallback;
  
  str = [mdstr UTF8String];
  hoedown_document_render(D, &B, (const uint8_t *) str, strlen(str));
  aString = [CLString stringWithBytes:(const char *) B.data length:B.size
			     encoding:CLUTF8StringEncoding];
  hoedown_document_free(D);
  hoedown_html_renderer_free(R);
  hoedown_buffer_uninit(&B);

  return aString;
}

-(CLDictionary *) linkAttributes
{
  return linkAttributes;
}

@end
